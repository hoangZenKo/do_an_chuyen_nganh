export function adminAccess(permissions: readonly string[], required: readonly string[], mfaRequired: boolean, mfaVerified: boolean) {
  const missing = required.filter(permission => !permissions.includes(permission));
  return { allowed: required.length > 0 && missing.length === 0 && (!mfaRequired || mfaVerified),
    missing, mfaNeeded: mfaRequired && !mfaVerified };
}
