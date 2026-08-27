#!/bin/bash
# Purpose: Create or reuse one stable code-signing identity for local Twist Spaces development.
# Usage: bash claude_jobs/setup-local-signing.sh
# Output: signing.local.json pins the certificate fingerprint; the identity stays in the login keychain.
# Security: Adds user-level trust for code signing only, never TLS or system-wide trust.
# Temporary private-key files are encrypted, restricted to the current user, and removed on exit.
# This is an explicit one-time setup, not an app installation or a distribution/notarization identity.
set -euo pipefail
umask 077

if [[ $# -ne 0 ]]; then
    printf 'Usage: bash claude_jobs/setup-local-signing.sh\n' >&2
    exit 64
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG="$ROOT/signing.local.json"
NAME="Twist Spaces Local Development"
# Target only the login keychain, not an unrelated custom default keychain.
KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"
if [[ ! -f "$KEYCHAIN" ]]; then
    printf 'The login keychain is unavailable. Open Keychain Access and unlock it, then retry.\n' >&2
    exit 1
fi

PINNED_IDENTITY=""
if [[ -f "$CONFIG" ]]; then
    PINNED_IDENTITY="$(/usr/bin/plutil -extract identity raw -expect string "$CONFIG")"
    if [[ ! "$PINNED_IDENTITY" =~ ^[A-F0-9]{40}$ ]]; then
        printf 'Invalid signing.local.json identity. Expected a certificate SHA-1 fingerprint.\n' >&2
        exit 1
    fi
fi

mkdir -p "$ROOT/.build"
WORK="$(/usr/bin/mktemp -d "$ROOT/.build/local-signing.XXXXXX")"
# Remove only the files created by this setup; never delete or replace keychain identities.
cleanup() {
    /bin/rm -f "$WORK/password" "$WORK/private-key.pem" "$WORK/identity.p12" "$WORK/certificate.pem" "$WORK/certificate.cnf" "$WORK/signing.local.json" "$WORK/keychain-error"
    /bin/rmdir "$WORK"
}
trap cleanup EXIT

if CERTIFICATES="$(/usr/bin/security find-certificate -a -c "$NAME" -Z "$KEYCHAIN" 2> "$WORK/keychain-error")"; then
    :
else
    STATUS=$?
    if [[ "$STATUS" -eq 44 ]]; then
        CERTIFICATES=""
    else
        cat "$WORK/keychain-error" >&2
        exit "$STATUS"
    fi
fi
FINGERPRINTS="$(printf '%s\n' "$CERTIFICATES" | /usr/bin/awk '/^SHA-1 hash:/ { print $3 }')"
COUNT="$(printf '%s\n' "$FINGERPRINTS" | /usr/bin/awk 'NF { count++ } END { print count+0 }')"
if [[ "$COUNT" -gt 1 ]]; then
    printf 'Multiple matching certificates exist. Resolve the identity explicitly; setup will not choose or replace one.\n' >&2
    exit 1
fi
if [[ -n "$PINNED_IDENTITY" && "$FINGERPRINTS" != "$PINNED_IDENTITY" ]]; then
    printf 'The pinned certificate is missing or differs from the login keychain. Restore the original identity; setup will not replace it.\n' >&2
    exit 1
fi

if [[ "$COUNT" -eq 0 ]]; then
    /usr/bin/openssl rand -hex 32 > "$WORK/password"
    cat > "$WORK/certificate.cnf" <<'CERTIFICATE'
[req]
prompt = no
distinguished_name = subject
x509_extensions = extensions
[subject]
CN = Twist Spaces Local Development
[extensions]
basicConstraints = critical,CA:FALSE
keyUsage = critical,digitalSignature
extendedKeyUsage = critical,codeSigning
subjectKeyIdentifier = hash
CERTIFICATE
    /usr/bin/openssl req -new -x509 -newkey rsa:3072 -sha256 -days 3650 \
        -config "$WORK/certificate.cnf" -passout "file:$WORK/password" \
        -keyout "$WORK/private-key.pem" -out "$WORK/certificate.pem"
    /usr/bin/openssl pkcs12 -export -name "$NAME" \
        -inkey "$WORK/private-key.pem" -in "$WORK/certificate.pem" \
        -passin fd:3 -passout fd:4 -out "$WORK/identity.p12" \
        3< "$WORK/password" 4< "$WORK/password"
    # Access is limited to codesign, not all applications; macOS may request keychain confirmation.
    /usr/bin/security import "$WORK/identity.p12" -k "$KEYCHAIN" \
        -P "$(cat "$WORK/password")" -T /usr/bin/codesign
else
    /usr/bin/security find-certificate -c "$NAME" -p "$KEYCHAIN" > "$WORK/certificate.pem"
fi

IDENTITY="$(/usr/bin/openssl x509 -in "$WORK/certificate.pem" -noout -fingerprint -sha1 | /usr/bin/sed 's/.*=//; s/://g')"
if [[ ! "$IDENTITY" =~ ^[A-F0-9]{40}$ ]]; then
    printf 'Unable to read the signing certificate fingerprint.\n' >&2
    exit 1
fi
IDENTITIES="$(/usr/bin/security find-identity -p codesigning "$KEYCHAIN")"
if ! printf '%s\n' "$IDENTITIES" | /usr/bin/awk -v identity="$IDENTITY" '$2 == identity { found=1 } END { exit !found }'; then
    printf 'The existing certificate has no usable private key. Restore its identity; setup will not generate a replacement.\n' >&2
    exit 1
fi

# Trust only this leaf certificate for code signing in the current user's trust domain.
# Do not change TLS trust, system trust, Gatekeeper, or Accessibility authorization.
VALID_IDENTITIES="$(/usr/bin/security find-identity -v -p codesigning "$KEYCHAIN")"
if ! printf '%s\n' "$VALID_IDENTITIES" | /usr/bin/awk -v identity="$IDENTITY" '$2 == identity { found=1 } END { exit !found }'; then
    /usr/bin/security add-trusted-cert -r trustRoot -p codeSign -k "$KEYCHAIN" "$WORK/certificate.pem"
    VALID_IDENTITIES="$(/usr/bin/security find-identity -v -p codesigning "$KEYCHAIN")"
fi
if ! printf '%s\n' "$VALID_IDENTITIES" | /usr/bin/awk -v identity="$IDENTITY" '$2 == identity { found=1 } END { exit !found }'; then
    printf 'The identity is not yet valid for code signing. Check the login keychain before retrying.\n' >&2
    exit 1
fi

printf '{\n  "identity": "%s"\n}\n' "$IDENTITY" > "$WORK/signing.local.json"
/bin/mv "$WORK/signing.local.json" "$CONFIG"
printf 'Local signing identity ready: %s\n' "$NAME"
printf 'Certificate fingerprint: %s\n' "$IDENTITY"
printf 'Configuration: %s\n' "$CONFIG"
