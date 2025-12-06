# Architecture Documentation

## System Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              INTERNET                                        │
│                                                                             │
│  Users: Windows laptops, Macs, iPads, iPhones, Linux devices                │
│  Apps: Tailscale, web apps, self-hosted services                            │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    │ HTTPS (TCP 443)
                                    │ Public DNS: adfs.yourdomain.com
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  NGINX REVERSE PROXY                                                        │
│  ─────────────────────────────────────────────────────────────────────────  │
│  Platform: Linux (Ubuntu/Debian recommended)                                │
│  Role: SSL termination, reverse proxy                                       │
│                                                                             │
│  Features:                                                                  │
│  - Let's Encrypt SSL certificate (certbot)                                  │
│  - Proxy pass to internal ADFS server                                       │
│  - Rate limiting (optional)                                                 │
│  - Access logs for security monitoring                                      │
│                                                                             │
│  Config: /etc/nginx/sites-available/adfs                                    │
│  Cert:   /etc/letsencrypt/live/adfs.yourdomain.com/                        │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    │ HTTPS (TCP 443) - Internal network
                                    │ Can use same cert or internal cert
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  ADFS SERVER (Windows Server 2019 Core)                                     │
│  ─────────────────────────────────────────────────────────────────────────  │
│  Hostname: adfs01.internal.domain                                           │
│  Role: Active Directory Federation Services                                 │
│                                                                             │
│  Components:                                                                │
│  - ADFS Windows Feature                                                     │
│  - gMSA Service Account (svc_adfs$)                                        │
│  - Windows Internal Database (WID)                                          │
│  - SSL Certificate (token signing, encryption, service)                     │
│                                                                             │
│  Endpoints:                                                                 │
│  - /adfs/ls/              - Sign-in page                                   │
│  - /adfs/oauth2/          - OAuth2/OIDC endpoints                          │
│  - /federationmetadata/   - SAML/WS-Fed metadata                           │
│  - /.well-known/          - OIDC discovery                                 │
│                                                                             │
│  State: C:\ADFSFromScratch\                                                 │
│  Logs:  C:\ADFSFromScratch\Logs\                                            │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    │ LDAP (TCP 389/636)
                                    │ Kerberos (TCP/UDP 88)
                                    │ DNS (TCP/UDP 53)
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  DOMAIN CONTROLLER                                                          │
│  ─────────────────────────────────────────────────────────────────────────  │
│  Platform: Windows Server (2016+)                                           │
│  Role: Active Directory Domain Services                                     │
│                                                                             │
│  Components:                                                                │
│  - AD DS (user accounts, groups)                                            │
│  - DNS Server (internal resolution)                                         │
│  - KDS Root Key (for gMSA password management)                             │
│                                                                             │
│  ADFS-Related Objects:                                                      │
│  - gMSA: CN=svc_adfs,CN=Managed Service Accounts,DC=...                    │
│  - SPN: host/adfs.yourdomain.com                                           │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Security Boundaries

### External Zone (Internet-facing)
- Only Nginx exposed (TCP 443)
- Let's Encrypt certificate (publicly trusted)
- No direct access to ADFS or DC

### Internal Zone (Protected)
- ADFS server on internal network
- DC never exposed externally
- Internal certificate optional (can reuse LE cert)

### Critical Security Rules
1. **Never run ADFS on Domain Controller**
2. **Never expose DC to internet**
3. **Use gMSA (no stored passwords)**
4. **TLS 1.2+ only**

## Data Flow

### OIDC Authentication (e.g., Tailscale)

```
1. User clicks "Sign in with SSO" in Tailscale
                    │
                    ▼
2. Tailscale redirects to ADFS authorize endpoint
   https://adfs.yourdomain.com/adfs/oauth2/authorize?
   client_id=tailscale&redirect_uri=...&scope=openid
                    │
                    ▼
3. Nginx receives request, proxies to ADFS
                    │
                    ▼
4. ADFS shows sign-in page
   User enters AD credentials
                    │
                    ▼
5. ADFS validates against Domain Controller (LDAP/Kerberos)
                    │
                    ▼
6. ADFS issues authorization code
   Redirects to Tailscale callback URL
                    │
                    ▼
7. Tailscale exchanges code for tokens
   POST https://adfs.yourdomain.com/adfs/oauth2/token
                    │
                    ▼
8. ADFS returns ID token + access token (JWTs)
   Contains claims: sub, email, groups, etc.
                    │
                    ▼
9. Tailscale validates tokens, creates session
   User is authenticated!
```

## Certificate Architecture

### Required Certificates

| Certificate | Purpose | Location | Renewal |
|------------|---------|----------|---------|
| Service Communications | HTTPS/SSL | Nginx + ADFS | Let's Encrypt (auto) |
| Token Signing | Signs SAML/JWT tokens | ADFS only | Self-signed (manual, yearly) |
| Token Decryption | Decrypts incoming tokens | ADFS only | Self-signed (manual, yearly) |

### Certificate Flow

```
Nginx (SSL Termination)
├── Uses Let's Encrypt cert for public HTTPS
└── Proxies to ADFS (can be HTTP internally or HTTPS)

ADFS Server
├── Service Communications: Same or different cert from Nginx
├── Token Signing: Self-signed, long-lived (1-3 years)
└── Token Decryption: Self-signed, long-lived (1-3 years)
```

## Network Ports

### External (Internet → Nginx)
| Port | Protocol | Purpose |
|------|----------|---------|
| 443 | HTTPS | All ADFS traffic |
| 80 | HTTP | Let's Encrypt ACME (redirect to 443) |

### Internal (Nginx → ADFS)
| Port | Protocol | Purpose |
|------|----------|---------|
| 443 | HTTPS | Proxied ADFS traffic |

### Internal (ADFS → DC)
| Port | Protocol | Purpose |
|------|----------|---------|
| 389 | LDAP | Directory queries |
| 636 | LDAPS | Secure directory queries |
| 88 | Kerberos | Authentication |
| 53 | DNS | Name resolution |
| 445 | SMB | Group Policy (optional) |

## Service Account (gMSA)

### What is gMSA?
Group Managed Service Account - AD manages the password automatically.

### Benefits
- 120-character random password
- Automatic rotation every 30 days
- No password stored in scripts or config
- Cannot be used for interactive logon

### Setup Requirements
1. Forest functional level 2012+
2. KDS Root Key created
3. Computer account allowed to retrieve password

### ADFS gMSA Details
```
Name:     svc_adfs$
Type:     msDS-GroupManagedServiceAccount
SPN:      host/adfs.yourdomain.com
          host/adfs01.internal.domain
Retrieve: adfs01$ (the ADFS server computer account)
```

## Database (WID)

### Why Windows Internal Database?
- Built into Windows Server
- No separate SQL Server needed
- Sufficient for single ADFS server
- Simple backup (stop service, copy files)

### Location
```
C:\Windows\WID\Data\
├── adfs.mdf          # Main database
└── adfs_log.ldf      # Transaction log
```

### Backup Strategy
1. Stop ADFS service
2. Copy WID files
3. Or: Use Windows Server Backup

## Scaling Considerations

### Current Design (Single Server)
- One ADFS server
- WID database
- Nginx as single proxy

### Future Scaling Options
1. **ADFS Farm**: Multiple ADFS servers + SQL backend
2. **Load Balancer**: Replace single Nginx with HA proxy
3. **Geo-redundancy**: Multiple sites with GSLB

### When to Scale
- >1000 concurrent users
- Uptime SLA >99.9%
- Multi-datacenter requirements
