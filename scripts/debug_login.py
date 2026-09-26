with open('lib/features/auth/login_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Build exact strings matching file content (LF only, no CRLF)
old = (
    "            _RoleQuickCard(\n"
    "              id: 'demo_admin',\n"
    "              role: 'Regulator',\n"
    "              subtitle: 'CDSCO Controller',\n"
    "              tag: 'Audit Surveillance',\n"
    "              icon: Icons.security_rounded,\n"
    "              color: MediLoopColors.ink,\n"
    "              onTap: auth.isLoading ? null : () => _demoLogin('admin'),\n"
    "            ),"
)

new = (
    "            _RoleQuickCard(\n"
    "              id: 'demo_regulator',\n"
    "              role: 'Regulator',\n"
    "              subtitle: 'CDSCO Inspector',\n"
    "              tag: 'Audit Surveillance',\n"
    "              icon: Icons.security_rounded,\n"
    "              color: MediLoopColors.ink,\n"
    "              onTap: auth.isLoading ? null : () => _demoLogin('regulator'),\n"
    "            ),"
)

# The file likely has => stored as => (not unicode)
# Let's try a simple find-replace on just the key differences
if "id: 'demo_admin'" in content:
    content = content.replace("id: 'demo_admin'", "id: 'demo_regulator'", 1)
    content = content.replace("subtitle: 'CDSCO Controller'", "subtitle: 'CDSCO Inspector'", 1)
    content = content.replace("() => _demoLogin('admin')", "() => _demoLogin('regulator')", 1)
    # Also fix the => stored as unicode arrow
    content = content.replace("() =\u003e _demoLogin('admin')", "() =\u003e _demoLogin('regulator')", 1)
    with open('lib/features/auth/login_screen.dart', 'w', encoding='utf-8') as f:
        f.write(content)
    print('Fixed individual fields')
    # Verify
    if "demo_regulator" in content:
        print('Verified: demo_regulator present')
    if "_demoLogin('regulator')" in content or "_demoLogin('regulator')" in content:
        print('Verified: regulator call present')
else:
    print('demo_admin NOT found at all')
