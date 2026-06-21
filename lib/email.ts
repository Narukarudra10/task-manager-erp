import https from 'https'

interface SendInviteEmailOptions {
  toEmail: string
  invitedByName: string
  groupName: string
  appUrl: string
  role: string
}

// Sends invite email via Resend REST API directly (no npm package needed)
export async function sendInviteEmail({
  toEmail,
  invitedByName,
  groupName,
  appUrl,
  role,
}: SendInviteEmailOptions): Promise<{ success: boolean; error?: string }> {
  if (!process.env.RESEND_API_KEY) {
    console.warn('[email] RESEND_API_KEY not set — skipping invite email.')
    return { success: false, error: 'Email service not configured (RESEND_API_KEY missing)' }
  }

  const roleLabel = role === 'admin' ? 'Admin' : 'Member'
  const signUpUrl = `${appUrl}/`

  const html = `
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
  <title>You're invited to ${groupName}</title>
</head>
<body style="margin:0;padding:0;background:#f0f4f8;font-family:'Segoe UI',Arial,sans-serif;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background:#f0f4f8;padding:40px 0;">
    <tr>
      <td align="center">
        <table width="600" cellpadding="0" cellspacing="0" style="background:#ffffff;border-radius:16px;overflow:hidden;box-shadow:0 4px 24px rgba(0,0,0,0.08);">
          <tr>
            <td style="background:linear-gradient(135deg,#0079BF 0%,#0091E6 100%);padding:36px 40px;text-align:center;">
              <h1 style="margin:0;color:#ffffff;font-size:28px;font-weight:700;letter-spacing:-0.5px;">&#128203; TaskFlow ERP</h1>
              <p style="margin:8px 0 0;color:rgba(255,255,255,0.85);font-size:15px;">You've been invited to join a workspace</p>
            </td>
          </tr>
          <tr>
            <td style="padding:40px;">
              <h2 style="margin:0 0 12px;color:#1a202c;font-size:22px;font-weight:700;">Hi there! &#128075;</h2>
              <p style="margin:0 0 20px;color:#4a5568;font-size:15px;line-height:1.6;">
                <strong style="color:#2d3748;">${invitedByName}</strong> has invited you to join the
                <strong style="color:#0079BF;">${groupName}</strong> workspace on TaskFlow ERP as a
                <strong>${roleLabel}</strong>.
              </p>
              <div style="background:#f7fafc;border:1px solid #e2e8f0;border-radius:12px;padding:20px 24px;margin:0 0 28px;">
                <table width="100%" cellpadding="0" cellspacing="0">
                  <tr>
                    <td>
                      <p style="margin:0 0 4px;font-size:12px;color:#718096;text-transform:uppercase;letter-spacing:0.8px;font-weight:600;">Workspace</p>
                      <p style="margin:0;font-size:18px;font-weight:700;color:#1a202c;">${groupName}</p>
                    </td>
                    <td align="right">
                      <span style="background:#ebf8ff;color:#0079BF;font-size:12px;font-weight:700;padding:4px 12px;border-radius:20px;">${roleLabel}</span>
                    </td>
                  </tr>
                  <tr>
                    <td colspan="2" style="padding-top:12px;">
                      <p style="margin:0;color:#718096;font-size:13px;">Invited by <strong>${invitedByName}</strong></p>
                    </td>
                  </tr>
                </table>
              </div>
              <table width="100%" cellpadding="0" cellspacing="0">
                <tr>
                  <td align="center" style="padding:8px 0 28px;">
                    <a href="${signUpUrl}" style="display:inline-block;background:linear-gradient(135deg,#0079BF,#0091E6);color:#ffffff;text-decoration:none;font-size:16px;font-weight:700;padding:14px 40px;border-radius:10px;">
                      Accept Invitation &rarr;
                    </a>
                  </td>
                </tr>
              </table>
              <div style="background:#fffbeb;border:1px solid #f6e05e;border-radius:10px;padding:16px 20px;margin-bottom:24px;">
                <p style="margin:0;color:#744210;font-size:13.5px;line-height:1.6;">
                  <strong>&#128204; How to join:</strong><br/>
                  If you already have an account, just <a href="${signUpUrl}" style="color:#0079BF;">sign in</a>.
                  If you're new, <a href="${signUpUrl}" style="color:#0079BF;">sign up</a> with
                  <strong>${toEmail}</strong> and you'll automatically be added to <strong>${groupName}</strong>.
                </p>
              </div>
              <p style="margin:0;color:#a0aec0;font-size:12.5px;line-height:1.5;">
                This invite was sent by ${invitedByName} via TaskFlow ERP. If you weren't expecting this, ignore it. Invites expire after 7 days.
              </p>
            </td>
          </tr>
          <tr>
            <td style="background:#f7fafc;padding:20px 40px;text-align:center;border-top:1px solid #e2e8f0;">
              <p style="margin:0;color:#a0aec0;font-size:12px;">&copy; 2025 TaskFlow ERP &mdash; Secure Team Task Management</p>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>`

  const fromAddress = process.env.RESEND_FROM_EMAIL || 'TaskFlow ERP <onboarding@resend.dev>'
  const subject = `${invitedByName} invited you to join "${groupName}" on TaskFlow ERP`

  const payload = JSON.stringify({
    from: fromAddress,
    to: [toEmail],
    subject,
    html,
  })

  return new Promise((resolve) => {
    const req = https.request(
      {
        hostname: 'api.resend.com',
        path: '/emails',
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${process.env.RESEND_API_KEY}`,
          'Content-Type': 'application/json',
          'Content-Length': Buffer.byteLength(payload),
        },
      },
      (res) => {
        let body = ''
        res.on('data', (chunk) => { body += chunk })
        res.on('end', () => {
          if (res.statusCode && res.statusCode >= 200 && res.statusCode < 300) {
            console.log('[email] Invite email sent to', toEmail)
            resolve({ success: true })
          } else {
            console.error('[email] Resend API error:', res.statusCode, body)
            resolve({ success: false, error: `Resend API error ${res.statusCode}: ${body}` })
          }
        })
      }
    )
    req.on('error', (err) => {
      console.error('[email] Request error:', err)
      resolve({ success: false, error: err.message })
    })
    req.write(payload)
    req.end()
  })
}
