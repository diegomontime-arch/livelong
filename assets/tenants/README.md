# Tenant branding assets

Each company folder holds the logo used to generate web/PWA icons.

```
assets/tenants/
├── m4life/logo.jpg      ← active tenant (M4LIFE USA)
├── portobello/          ← future tenant
└── default/             ← fallback
```

## Regenerate icons

```bash
pip3 install Pillow
python3 scripts/generate_web_icons.py --tenant=m4life
```

Optional: pass a new logo file directly:

```bash
python3 scripts/generate_web_icons.py --tenant=m4life --source=/path/to/logo.jpg
```

Then deploy: `./save.sh "feat: update tenant icons"`

## Future (Firestore)

`companies/{companyId}.iconUrl` will point to hosted logos; this folder is the build-time source until dynamic icons are wired in the app.
