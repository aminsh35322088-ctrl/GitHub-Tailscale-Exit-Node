[English](./README.en.md)

# GitHub Tailscale Exit Node — راهنمای فارسی 🇮🇷

یک Tailscale Exit Node که روی GitHub Actions اجرا می‌شود و با مکانیزم‌های self-relaunch و watchdog سعی می‌کند تا حد ممکن آنلاین بماند.

> ⚠️ **نکته مهم:** GitHub Actions یک VPS دائمی نیست. Runnerها موقتی هستند و اجرای هر Job محدودیت زمانی دارد. این پروژه برای uptime بالا و recovery خودکار طراحی شده، اما 24/7 را تضمین نمی‌کند.

## این پروژه چیست؟

GitHub Actions یک Linux runner موقت ایجاد می‌کند، Tailscale را روی آن اجرا می‌کند و Runner را به‌عنوان Exit Node در Tailnet شما معرفی می‌کند.

## 🚀 آموزش راه‌اندازی از صفر

این راهنما برای کاربران مبتدی نوشته شده است؛ نیازی به VPS یا Linux ندارید.

### 1. Fork کردن پروژه

روی **Fork** بزنید و پروژه را داخل حساب GitHub خودتان کپی کنید. از این مرحله به بعد Workflowها را در Fork خودتان اجرا کنید.

### 2. ساخت Tailscale و Tag

وارد حساب Tailscale شوید و Tag زیر را برای Nodeهای این پروژه در Policy/ACL خود تعریف کنید:

```text
tag:exit
```

OAuth Client شما باید اجازه استفاده از این Tag را داشته باشد.

### 3. ساخت OAuth Client

در پنل Tailscale یک **OAuth Client** بسازید و اجازه استفاده از `tag:exit` را به آن بدهید.

مقادیر زیر را نگه دارید:

```text
TS_OAUTH_CLIENT_ID
TS_OAUTH_SECRET
```

`TS_OAUTH_SECRET` را هیچ‌وقت داخل کد یا Commit قرار ندهید.

### 4. ساخت Fine-grained PAT

در GitHub از مسیر **Settings → Developer settings → Personal access tokens → Fine-grained tokens** یک Token بسازید.

Repository access را فقط به Fork خودتان محدود کنید.

برای استفاده کامل از watchdog، این Permissionها را بدهید:

```text
Actions: Read and write
Variables: Read and write
```

`Variables: Read and write` برای قابلیت **`action=stop`** لازم است، چون watchdog باید بتواند متغیر `EXIT_NODE_DISABLED` را تغییر دهد.

Token را با نام زیر به Repository secrets اضافه کنید:

```text
ACTIONS_WATCHDOG_TOKEN
```

### 5. اضافه‌کردن Secrets

در Fork خودتان بروید به:

**Settings → Secrets and variables → Actions → New repository secret**

این موارد را اضافه کنید:

| Name | Value |
|---|---|
| `TS_OAUTH_CLIENT_ID` | Tailscale OAuth Client ID |
| `TS_OAUTH_SECRET` | Tailscale OAuth Client Secret |
| `ACTIONS_WATCHDOG_TOKEN` | Fine-grained GitHub PAT |

### 6. فعال‌کردن Actions

تب **Actions** را باز کنید و در صورت درخواست GitHub، Workflowها را فعال کنید.

### 7. اجرای اولیه

به **Actions → Tailscale Exit Node Watchdog → Run workflow** بروید و انتخاب کنید:

```text
action = ensure
```

سپس **Run workflow** را بزنید.

### 8. بررسی Exit Node

در **Actions → Tailscale Exit Node** اجرای جدید را باز کنید. پس از موفقیت، Runner موقت باید در Tailscale به‌عنوان یک Node با `tag:exit` دیده شود.

اگر Tailscale درخواست Approval کرد، آن را در Admin Console تأیید کنید.

### 9. اتصال دستگاه خودتان

روی گوشی یا کامپیوتر مقصد:

1. Tailscale را نصب و وارد همان Tailnet شوید.
2. Tailscale را روشن کنید.
3. بخش **Exit Node** را باز کنید.
4. GitHub Actions runner را انتخاب کنید.

برای تست، IP عمومی دستگاه را قبل و بعد از فعال‌کردن Exit Node مقایسه کنید.

## 🔄 سیستم چگونه آنلاین می‌ماند؟

یک GitHub Actions Job نمی‌تواند برای همیشه اجرا شود. بنابراین پروژه Runها را پشت سر هم زنجیر می‌کند:

```text
Run #1 → Run #2 → Run #3 → ...
```

چند مسیر Recovery وجود دارد:

- **Self-relaunch:** اجرای فعلی قبل از پایان، اجرای بعدی را آماده می‌کند.
- **Relaunch recovery:** در صورت شکست handover یا startup تلاش مجدد انجام می‌شود.
- **Watchdog:** Runهای فعال، queued و stale را بررسی می‌کند.
- **Scheduled backstop:** یک مسیر پشتیبان برای شروع مجدد زنجیره است.
- **Crash-loop protection:** از ایجاد بی‌نهایت Run در صورت failure پشت‌سرهم جلوگیری می‌کند.

منطق recovery در `.github/scripts/ensure-exit-node.sh` متمرکز است.

## 🛑 توقف و اجرای دوباره

برای توقف:

**Actions → Tailscale Exit Node Watchdog → Run workflow → `action=stop`**

برای اجرای دوباره، `EXIT_NODE_DISABLED` را روی `false` قرار دهید یا حذف کنید و سپس `action=ensure` را اجرا کنید.

> برای `action=stop` حتماً `ACTIONS_WATCHDOG_TOKEN` باید وجود داشته باشد و Permission مربوط به **Variables: Read and write** را داشته باشد.

## 🛠️ عیب‌یابی

### Workflow اجرا نمی‌شود

Actions را فعال کنید، وجود Secretها را بررسی کنید و مطمئن شوید PAT دارای **Actions: Read and write** است.

### `action=stop` کار نمی‌کند

بررسی کنید `ACTIONS_WATCHDOG_TOKEN` تنظیم شده باشد و PAT دارای هر دو Permission زیر باشد:

```text
Actions: Read and write
Variables: Read and write
```

اگر PAT وجود نداشته باشد، watchdog باید قبل از درخواست API خطای واضحی نمایش دهد.

### خطای Tailscale authentication

`TS_OAUTH_CLIENT_ID`، `TS_OAUTH_SECRET` و دسترسی OAuth Client به `tag:exit` را بررسی کنید.

### Node دیده می‌شود ولی Exit Node نیست

Approvalهای Tailscale، Tag و logهای Workflow را بررسی کنید.

### Exit Node بعداً قطع شد

Runnerهای GitHub موقتی هستند. سیستم recovery خودکار دارد، اما uptime دائمی را تضمین نمی‌کند.

## 🔐 امنیت

- `TS_OAUTH_SECRET` و `ACTIONS_WATCHDOG_TOKEN` را Commit نکنید.
- PAT را فقط به Repository خودتان محدود کنید.
- حداقل Permission لازم را بدهید.
- در صورت افشای Credential، فوراً آن را revoke/rotate کنید.

## 🧪 تست‌ها

منطق handover را می‌توان بدون شبکه تست کرد:

```bash
bash .github/scripts/tests/ensure-exit-node.test.sh
```

## 📚 منابع رسمی

- [Tailscale GitHub Action](https://tailscale.com/docs/integrations/github/github-action)
- [Tailscale OAuth clients](https://tailscale.com/docs/features/oauth-clients)
- [Tailscale Exit Nodes](https://tailscale.com/docs/features/exit-nodes)
- [GitHub Actions](https://docs.github.com/actions)

## ⚠️ محدودیت مهم

این پروژه یک روش خلاقانه برای اجرای Tailscale Exit Node روی GitHub Actions است و جایگزین VPS یا سرور دائمی نیست. GitHub می‌تواند Runnerها را متوقف کند، Workflowها را محدود کند یا دسترسی به Actions را تغییر دهد؛ بنابراین **تضمین uptime دائمی یا 24/7 وجود ندارد**.
