"""
Servicio de envío de correo corporativo NutriTrack.
Configuración por variables de entorno.
"""
import os
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from typing import Optional

# Remitente corporativo NutriTrack (configurable por env)
NUTRITRACK_EMAIL = os.getenv("NUTRITRACK_EMAIL", "noreply@nutritrack.app")
NUTRITRACK_EMAIL_PASSWORD = os.getenv("NUTRITRACK_EMAIL_PASSWORD", "")
SMTP_HOST = os.getenv("SMTP_HOST", "smtp.gmail.com")
SMTP_PORT = int(os.getenv("SMTP_PORT", "587"))
SMTP_USE_TLS = os.getenv("SMTP_USE_TLS", "true").lower() == "true"
# Nombre visible en los correos
NUTRITRACK_SENDER_NAME = os.getenv("NUTRITRACK_SENDER_NAME", "NutriTrack")


def is_email_configured() -> bool:
    """Comprueba si el correo corporativo está configurado."""
    return bool(NUTRITRACK_EMAIL and NUTRITRACK_EMAIL_PASSWORD and SMTP_HOST)


def send_email(
    to_email: str,
    subject: str,
    body_html: str,
    body_plain: Optional[str] = None,
) -> bool:
    """
    Envía un correo desde la cuenta corporativa NutriTrack.
    Returns True si se envió correctamente, False en caso contrario.
    """
    if not is_email_configured():
        print("⚠️ Email no configurado: NUTRITRACK_EMAIL, NUTRITRACK_EMAIL_PASSWORD y SMTP_HOST deben estar definidos")
        return False

    if not body_plain:
        import re
        body_plain = re.sub(r"<[^>]+>", "", body_html).strip()

    msg = MIMEMultipart("alternative")
    msg["Subject"] = subject
    msg["From"] = f"{NUTRITRACK_SENDER_NAME} <{NUTRITRACK_EMAIL}>"
    msg["To"] = to_email

    msg.attach(MIMEText(body_plain, "plain", "utf-8"))
    msg.attach(MIMEText(body_html, "html", "utf-8"))

    try:
        with smtplib.SMTP(SMTP_HOST, SMTP_PORT) as server:
            if SMTP_USE_TLS:
                server.starttls()
            server.login(NUTRITRACK_EMAIL, NUTRITRACK_EMAIL_PASSWORD)
            server.sendmail(NUTRITRACK_EMAIL, to_email, msg.as_string())
        print(f"✅ Email enviado a {to_email}: {subject}")
        return True
    except Exception as e:
        print(f"❌ Error enviando email a {to_email}: {e}")
        return False
