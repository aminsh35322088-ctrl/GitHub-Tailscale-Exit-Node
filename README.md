[English](./README.en.md)

# supreme-palm-tree — راهنمای فارسی 🇮🇷

یک Tailscale Exit Node که روی GitHub Actions اجرا می‌شود و با مکانیزم‌های self-relaunch و watchdog سعی می‌کند تا حد ممکن آنلاین بماند.

> ⚠️ **نکته مهم:** GitHub Actions یک سرور VPS دائمی نیست. Runnerها موقتی هستند و اجرای هر Job محدودیت زمانی دارد. این پروژه با زنجیره‌کردن اجراها و مکانیزم recovery برای uptime بالا طراحی شده، اما تضمین 24/7 نمی‌دهد.

## این پروژه دقیقاً چه کار می‌کند؟

به‌جای اینکه Exit Node را روی یک کامپیوتر یا VPS دائمی اجرا کنید، GitHub Actions یک Linux runner موقت می‌سازد و Tailscale را روی آن اجرا می‌کند.

هر اجرا حداکثر برای مدت مشخصی آنلاین می‌ماند و قبل از پایان، اجرای بعدی را آماده می‌کند. در کنار آن، watchdog وضعیت سیستم را بررسی می‌کند و اگر Exit Node از کار افتاده باشد، دوباره آن را راه‌اندازی می‌کند.

ساختار کلی:

```text
GitHub Actions Runner
        │
        ▼
   Tailscale Node
        │
        ▼
    tag:exit
        │
        ▼
    Exit Node
        │
        ├── Self-relaunch → اجرای بعدی
        │
        └── Watchdog → بررسی و Recovery
```

---

# 🚀 آموزش راه‌اندازی از صفر

این راهنما برای کاربری نوشته شده که حتی قبلاً با GitHub Actions یا Tailscale کار نکرده است.

## پیش‌نیازها

- یک حساب GitHub
- یک حساب Tailscale
- دسترسی به GitHub Actions
- یک دستگاه مقصد که Tailscale روی آن نصب باشد

---

## 1. ساخت Fork از پروژه

ابتدا وارد صفحه اصلی پروژه شوید و روی **Fork** بزنید.

بعد از Fork، یک کپی از پروژه داخل حساب GitHub خودتان خواهید داشت.

از این به بعد **Fork خودتان** را استفاده کنید، نه ریپوی اصلی.

---

## 2. ساخت حساب Tailscale و Tag

اگر حساب Tailscale ندارید، یک حساب بسازید و وارد پنل شوید.

این پروژه از Tag زیر استفاده می‌کند:

```text
tag:exit
```

در Policy/ACL تیل‌اسکیل، Tag را طوری تنظیم کنید که OAuth Client شما بتواند آن را به Node اختصاص دهد.

---

## 3. ساخت Tailscale OAuth Client

در پنل مدیریت Tailscale یک **OAuth Client** بسازید و اجازه استفاده از `tag:exit` را به آن بدهید.

دو مقدار دریافت می‌کنید:

```text
TS_OAUTH_CLIENT_ID
TS_OAUTH_SECRET
```

> **هشدار:** `TS_OAUTH_SECRET` را داخل کد، README، Issue، Commit یا Chat عمومی قرار ندهید.

---

## 4. ساخت GitHub Fine-grained PAT

برای watchdog یک **Fine-grained Personal Access Token** بسازید.

Repository access را فقط به **Fork خودتان** محدود کنید.

حداقل permission لازم:

```text
Actions: Read and write
```

`Metadata: Read-only` نیز معمولاً به‌صورت پیش‌فرض لازم است.

سپس Token را به‌عنوان Secret زیر در Fork ذخیره کنید:

```text
ACTIONS_WATCHDOG_TOKEN
```

> Token را مثل رمز عبور نگه دارید و هرگز Commit نکنید.

---

## 5. اضافه‌کردن Secrets به GitHub

در Fork خودتان بروید به:

**Settings → Secrets and variables → Actions → New repository secret**

این Secretها را بسازید:

| نام | مقدار |
|---|---|
| `TS_OAUTH_CLIENT_ID` | OAuth Client ID از Tailscale |
| `TS_OAUTH_SECRET` | OAuth Client Secret از Tailscale |
| `ACTIONS_WATCHDOG_TOKEN` | Fine-grained PAT |

---

## 6. فعال‌کردن GitHub Actions

وارد تب **Actions** شوید و اگر GitHub خواست، Workflowها را فعال کنید.

---

## 7. اولین اجرای Exit Node

به مسیر زیر بروید:

**Actions → Tailscale Exit Node Watchdog → Run workflow**

مقدار زیر را انتخاب کنید:

```text
action = ensure
```

سپس **Run workflow** را بزنید.

Watchdog بررسی می‌کند که آیا Exit Node فعال است یا نه و در صورت نیاز Workflow مربوط به Exit Node را اجرا می‌کند.

---

## 8. بررسی Runner

در **Actions → Tailscale Exit Node** اجرای جدید را باز کنید.

پس از موفقیت، یک Linux runner موقت در Tailscale با هویت `tag:exit` خواهید دید.

---

## 9. تأیید Exit Node

در Tailscale Admin Console دستگاه جدید را پیدا کنید. اگر Tailscale درخواست approval کرد، آن را تأیید کنید.

Workflow، Runner را به‌عنوان Exit Node advertise می‌کند. سپس روی دستگاه مقصد:

**Tailscale → Exit node → انتخاب GitHub runner**

را انجام دهید.

---

## 10. تست اتصال

IP عمومی دستگاه مقصد را قبل و بعد از فعال‌کردن Exit Node مقایسه کنید. در صورت موفقیت باید IP خروجی Runner را مشاهده کنید.

---

# 🔄 سیستم چگونه آنلاین می‌ماند؟

GitHub Actions اجازه اجرای نامحدود یک Job را نمی‌دهد. بنابراین پروژه به‌جای یک اجرای دائمی، چند Run را پشت سر هم زنجیر می‌کند.

```text
Run #1 → Run #2 → Run #3 → ...
```

چند لایه recovery وجود دارد:

1. **Self-handover:** اجرای فعلی قبل از پایان، اجرای بعدی را آماده می‌کند.
2. **Relaunch:** اگر handover موفق نشود، مسیر recovery تلاش می‌کند Run جدید ایجاد کند.
3. **Watchdog:** وضعیت Runها را بررسی می‌کند و Runهای گمشده یا stale را recovery می‌کند.
4. **Schedule:** یک مسیر پشتیبان برای راه‌اندازی مجدد زنجیره است.

همه این مسیرها از `.github/scripts/ensure-exit-node.sh` استفاده می‌کنند و اگر Run فعال یا queued وجود داشته باشد، اجرای اضافه ایجاد نمی‌کنند.

---

# 🛑 توقف و اجرای دوباره

برای توقف:

**Actions → Tailscale Exit Node Watchdog → Run workflow**

و:

```text
action = stop
```

را اجرا کنید.

برای اجرای دوباره، `EXIT_NODE_DISABLED` را روی `false` قرار دهید یا حذف کنید و سپس watchdog را با `action=ensure` اجرا کنید.

---

# 🧯 Crash-loop protection

اگر چند Run پشت سر هم در مدت کوتاهی fail شوند، سیستم از ایجاد بی‌نهایت Run جلوگیری می‌کند تا Actions minutes بی‌دلیل مصرف نشود.

علت‌های رایج:

- اشتباه بودن OAuth credentials
- منقضی شدن OAuth Client
- نداشتن دسترسی `tag:exit`
- مشکل تنظیمات GitHub Actions

---

# 🛠️ عیب‌یابی

### Workflow اجرا نمی‌شود

بررسی کنید:

1. Actions برای Fork فعال باشد.
2. `ACTIONS_WATCHDOG_TOKEN` وجود داشته باشد و permission **Actions: Read and write** داشته باشد.
3. Workflowها در `.github/workflows/` وجود داشته باشند.
4. `EXIT_NODE_DISABLED` روی `true` نباشد.
5. Workflow را از Fork خودتان اجرا کنید.

### خطای احراز هویت Tailscale

`TS_OAUTH_CLIENT_ID` و `TS_OAUTH_SECRET`، وضعیت OAuth Client و دسترسی آن به `tag:exit` را بررسی کنید.

### Node در Tailscale دیده می‌شود ولی Exit Node نیست

Logهای Workflow و تنظیمات approval در Tailscale را بررسی کنید.

### Exit Node بعداً قطع شد

Runnerهای GitHub موقتی هستند و ممکن است Job متوقف شود. پروژه recovery خودکار دارد، اما uptime دائمی را تضمین نمی‌کند.

---

# 🔐 نکات امنیتی

- هرگز `TS_OAUTH_SECRET` یا `ACTIONS_WATCHDOG_TOKEN` را Commit نکنید.
- PAT را فقط به Repository خودتان محدود کنید.
- فقط permissionهای موردنیاز را بدهید.
- اگر Credential لو رفت، فوراً آن را revoke/rotate کنید.
- فقط دستگاه‌ها و کاربران مورداعتماد را به Exit Node خودتان دسترسی دهید.

---

# 🧪 تست‌ها

منطق handover را می‌توان بدون شبکه تست کرد:

```bash
bash .github/scripts/tests/ensure-exit-node.test.sh
```

---

# 📚 منابع رسمی

- Tailscale GitHub Action: https://tailscale.com/docs/integrations/github/github-action
- Tailscale OAuth clients: https://tailscale.com/docs/features/oauth-clients
- Tailscale Exit Nodes: https://tailscale.com/docs/features/exit-nodes
- GitHub Actions: https://docs.github.com/actions

---

# ⚠️ محدودیت مهم

این پروژه یک روش خلاقانه برای اجرای Tailscale Exit Node روی GitHub Actions است، اما جایگزین VPS یا سرور دائمی نیست.

GitHub می‌تواند Runnerها را متوقف کند، Workflowها را محدود کند یا دسترسی به Actions را تغییر دهد. بنابراین حتی با self-relaunch و watchdog نیز **تضمین uptime دائمی یا 24/7 وجود ندارد**.
