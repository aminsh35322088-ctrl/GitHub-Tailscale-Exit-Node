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

به این موارد نیاز دارید:

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

## 2. ساخت حساب Tailscale

اگر حساب Tailscale ندارید، یک حساب بسازید و وارد پنل شوید.

بعد از ورود، باید یک Tag برای Exit Node بسازید.

### ساخت Tag

در پنل Tailscale، بخش ACL / Policy را باز کنید و Tag زیر را تعریف کنید:

```text
 tagOwners:
   "tag:exit": ["autogroup:admin"]
```

اگر Policy شما از قبل وجود دارد، فقط بخش مربوط به `tag:exit` را با ساختار Policy فعلی خودتان هماهنگ کنید.

> اگر با ACL/Policy آشنا نیستید، از مستندات رسمی Tailscale استفاده کنید. Tag باید طوری تنظیم شود که OAuth Client شما بتواند آن را به Node اختصاص دهد.

---

## 3. ساخت Tailscale OAuth Client

در پنل مدیریت Tailscale یک OAuth Client بسازید.

Client باید اجازه استفاده از Tag زیر را داشته باشد:

```text
 tag:exit
```

در پایان دو مقدار دریافت می‌کنید:

```text
TS_OAUTH_CLIENT_ID
TS_OAUTH_SECRET
```

این دو مقدار را نگه دارید؛ بعداً وارد GitHub می‌کنیم.

> **هشدار:** `TS_OAUTH_SECRET` را داخل کد، README، Issue، Commit یا Chat عمومی قرار ندهید.

---

## 4. ساخت GitHub Fine-grained PAT

برای اینکه watchdog بتواند مستقل از `GITHUB_TOKEN` وضعیت Workflowها را بررسی و Workflow بعدی را اجرا کند، یک Personal Access Token بسازید.

در GitHub وارد:

**Settings → Developer settings → Personal access tokens → Fine-grained tokens**

شوید و یک Token جدید بسازید.

### Repository access

Token را فقط به **Fork خودتان** محدود کنید.

### Repository permissions

حداقل دسترسی لازم برای این پروژه:

```text
Actions: Read and write
```

اگر نسخه‌ای از watchdog شما از Repository Variables برای Kill Switch استفاده می‌کند، دسترسی لازم برای مدیریت Variables را نیز مطابق workflow همان نسخه تنظیم کنید.

بعد از ساخت Token، مقدار آن را فقط یک بار مشاهده می‌کنید. آن را امن نگه دارید.

---

## 5. اضافه‌کردن Secrets به GitHub

در Fork خودتان بروید به:

**Settings → Secrets and variables → Actions**

سپس در بخش **Repository secrets** این دو Secret را بسازید:

| نام | مقدار |
|---|---|
| `TS_OAUTH_CLIENT_ID` | OAuth Client ID از Tailscale |
| `TS_OAUTH_SECRET` | OAuth Client Secret از Tailscale |

اگر می‌خواهید watchdog مستقل PAT-based داشته باشید، Token را نیز با نام زیر اضافه کنید:

| نام | مقدار |
|---|---|
| `ACTIONS_WATCHDOG_TOKEN` | Fine-grained PAT ساخته‌شده در مرحله قبل |

### خیلی مهم

این مقادیر را **داخل فایل‌های Workflow قرار ندهید**.

اشتباه:

```yaml
TS_OAUTH_SECRET: my-secret-here
```

درست:

```yaml
TS_OAUTH_SECRET: ${{ secrets.TS_OAUTH_SECRET }}
```

---

# 6. فعال‌کردن GitHub Actions

وارد تب **Actions** ریپوی Fork شده شوید.

اگر GitHub از شما خواست Workflowها را فعال کنید، گزینه **I understand my workflows, go ahead and enable them** یا گزینه مشابه را بزنید.

حالا باید Workflowهای پروژه را ببینید.

---

# 7. اولین اجرای Exit Node

برای اولین اجرا پیشنهاد می‌شود از watchdog استفاده کنید.

در GitHub بروید به:

**Actions → Tailscale Exit Node Watchdog**

سپس:

**Run workflow**

و مقدار:

```text
action = ensure
```

را انتخاب کنید.

بعد روی **Run workflow** بزنید.

Watchdog بررسی می‌کند که آیا Exit Node فعال است یا نه و در صورت نیاز Workflow مربوط به Exit Node را اجرا می‌کند.

---

# 8. بررسی اجرای Workflow

روی اجرای جدید کلیک کنید و وارد Jobها شوید.

اگر همه‌چیز درست باشد، Runner ساخته می‌شود، Tailscale نصب و اجرا می‌شود و Node با Tag زیر وارد Tailnet شما می‌شود:

```text
 tag:exit
```

---

# 9. تأیید Node در Tailscale

وارد پنل Tailscale شوید و بخش **Machines / Devices** را باز کنید.

باید یک Linux device جدید ببینید.

نام دستگاه ممکن است به‌دلیل ephemeral بودن GitHub Runner در اجراهای مختلف تغییر کند.

مطمئن شوید Node با `tag:exit` شناخته شده است.

---

# 10. فعال‌کردن Exit Node

در Tailscale Admin Console، دستگاهی که GitHub Actions ساخته را پیدا کنید.

در تنظیمات آن، قابلیت **Exit Node** را تأیید/فعال کنید.

اگر Tailscale برای approval یا استفاده از Exit Node نیاز به تأیید داشته باشد، همان‌جا آن را تأیید کنید.

---

# 11. استفاده از Exit Node روی گوشی یا کامپیوتر

روی دستگاهی که می‌خواهید اینترنتش از Exit Node عبور کند:

1. Tailscale را نصب کنید.
2. با همان Tailnet وارد شوید.
3. Tailscale را روشن کنید.
4. گزینه **Exit Node** را باز کنید.
5. Linux node مربوط به GitHub Actions را انتخاب کنید.

از این لحظه ترافیک اینترنت دستگاه شما می‌تواند از طریق GitHub Actions runner عبور کند.

---

# 12. تست اینکه Exit Node واقعاً کار می‌کند

روی دستگاه مقصد، IP عمومی را قبل و بعد از فعال‌کردن Exit Node مقایسه کنید.

اگر Exit Node درست کار کند، IP عمومی باید مطابق مسیر خروجی Runner تغییر کند.

همچنین می‌توانید از یک سرویس بررسی IP عمومی استفاده کنید.

> اگر IP تغییر نکرد، ابتدا بررسی کنید که Exit Node در Tailscale انتخاب شده و approvalهای لازم انجام شده باشند.

---

# 🔄 سیستم چگونه آنلاین می‌ماند؟

GitHub Actions اجازه اجرای نامحدود یک Job را نمی‌دهد. بنابراین پروژه به‌جای یک اجرای دائمی، چند Run را پشت سر هم زنجیر می‌کند.

به‌صورت مفهومی:

```text
Run #1
  │
  ├── Exit Node فعال
  │
  ├── نزدیک پایان → Run #2 را آماده می‌کند
  │
  ▼
Run #2
  │
  ├── Exit Node فعال
  │
  └── → Run #3
  │
  ▼
  ...
```

در کنار self-relaunch، watchdog هم سیستم را زیر نظر دارد.

اگر Run فعالی وجود نداشته باشد، watchdog می‌تواند اجرای جدید را dispatch کند.

اگر Run گیر کرده یا stale شده باشد، منطق recovery می‌تواند آن را جایگزین کند.

این چندلایه بودن باعث می‌شود از بین رفتن یک مسیر recovery الزاماً به خاموش‌شدن کامل Exit Node منجر نشود.

---

# 🛑 متوقف‌کردن Exit Node

اگر Workflow فعلی Watchdog شما از Kill Switch پشتیبانی می‌کند:

**Actions → Tailscale Exit Node Watchdog → Run workflow**

و:

```text
action = stop
```

را اجرا کنید.

این کار باید ابتدا زنجیره relaunch را متوقف کند و سپس Runهای فعال را cancel کند.

فقط Cancel کردن Run کافی نیست، چون Run لغوشده ممکن است triggerهای recovery را فعال کند.

---

# ▶️ اجرای دوباره

بعد از Stop، Kill Switch را به حالت فعال برگردانید:

```text
EXIT_NODE_DISABLED = false
```

یا اگر پروژه/نسخه فعلی شما از حذف Variable به‌عنوان حالت فعال استفاده می‌کند، آن Variable را حذف کنید.

سپس دوباره watchdog را با:

```text
action = ensure
```

اجرا کنید.

---

# 🧯 Crash-loop protection

اگر Exit Node چند بار پشت سر هم خیلی سریع fail شود، سیستم نباید بی‌نهایت GitHub Actions Run ایجاد کند.

در این حالت watchdog/recovery می‌تواند dispatch کردن Run جدید را متوقف کند تا Actions minutes بی‌دلیل مصرف نشود.

یکی از علت‌های رایج crash-loop:

- اشتباه بودن `TS_OAUTH_CLIENT_ID`
- اشتباه بودن `TS_OAUTH_SECRET`
- منقضی یا غیرفعال‌شدن OAuth Client
- نداشتن مالکیت `tag:exit`
- تغییر Policy یا ACL مربوط به Tailscale
- تغییر permissionهای GitHub Token

اول این موارد را بررسی کنید.

---

# 🔐 نکات امنیتی

### Secretها را Commit نکنید

هرگز این موارد را در Git commit نکنید:

```text
TS_OAUTH_SECRET
ACTIONS_WATCHDOG_TOKEN
```

### PAT را محدود کنید

Fine-grained PAT را فقط به Repository خودتان محدود کنید و فقط permissionهای لازم را بدهید.

### اگر Token لو رفت

اگر PAT یا OAuth Secret به هر شکلی عمومی شد:

1. فوراً Token/Secret را revoke کنید.
2. یک Token/Secret جدید بسازید.
3. Secret قبلی را از GitHub حذف یا جایگزین کنید.
4. History ریپو را هم بررسی کنید.

---

# 🛠️ عیب‌یابی

## Workflow اجرا نمی‌شود

این موارد را بررسی کنید:

- GitHub Actions برای Fork فعال است.
- Workflowها روی branch موردنظر وجود دارند.
- Secretها دقیقاً با نام صحیح اضافه شده‌اند.
- Workflow permissionهای لازم را دارد.
- PAT منقضی نشده است.

## Tailscale Node ساخته نمی‌شود

بررسی کنید:

- `TS_OAUTH_CLIENT_ID` صحیح است.
- `TS_OAUTH_SECRET` صحیح است.
- OAuth Client اجازه استفاده از `tag:exit` را دارد.
- Policy/ACL تیل‌اسکیل Tag را مجاز کرده است.

## Node در Tailscale دیده می‌شود ولی Exit Node نیست

بررسی کنید:

- Node با `tag:exit` ایجاد شده باشد.
- Exit Node در Admin Console تأیید شده باشد.
- دستگاه مقصد Exit Node صحیح را انتخاب کرده باشد.

## Exit Node بعد از مدتی قطع شد

اولین کار این است که تب **Actions** را بررسی کنید.

به آخرین Run مربوط به Exit Node و Watchdog بروید و ببینید کدام مرحله fail شده است.

در حالت عادی self-relaunch و watchdog باید اجرای بعدی را ایجاد کنند. اگر این اتفاق نیفتاد، logهای watchdog را بررسی کنید.

---

# 🧪 تست منطق Recovery

تست‌های آفلاین پروژه بدون نیاز به شبکه قابل اجرا هستند:

```bash
bash .github/scripts/tests/ensure-exit-node.test.sh
```

این تست‌ها برای بررسی منطق dispatch، stale-run handling و recovery استفاده می‌شوند.

---

# ⚙️ تنظیمات پیشرفته

تنظیمات قابل تغییر پروژه در `env:` بالای Workflow مربوط به Exit Node و همچنین defaultهای موجود در:

```text
.github/scripts/ensure-exit-node.sh
```

قرار دارند.

قبل از تغییر این مقادیر، ابتدا منطق concurrency و handover را درک کنید؛ تغییر اشتباه ممکن است باعث اجرای همزمان چند Exit Node یا ایجاد فاصله بین Runها شود.

---

# 📚 منابع رسمی

- [Tailscale — GitHub Actions](https://tailscale.com/docs/integrations/github/github-action)
- [Tailscale — Exit Nodes](https://tailscale.com/kb/1103/exit-nodes/)
- [Tailscale — OAuth Clients](https://tailscale.com/kb/1215/oauth-clients/)
- [Tailscale — ACLs / Grants](https://tailscale.com/kb/1018/acls/)
- [GitHub — Fine-grained personal access tokens](https://docs.github.com/authentication/keeping-your-account-and-data-secure/creating-a-personal-access-token)
- [GitHub — GitHub Actions](https://docs.github.com/actions)

---

# ⚠️ محدودیت مهم

این پروژه یک روش خلاقانه برای اجرای Tailscale Exit Node روی GitHub Actions است، اما نباید آن را جایگزین VPS یا سرور دائمی در نظر گرفت.

GitHub می‌تواند Runnerها را متوقف کند، Workflowها را محدود کند یا رفتار Actions را تغییر دهد. بنابراین حتی با self-relaunch و watchdog نیز **تضمین uptime دائمی وجود ندارد**.

اگر به uptime واقعی 24/7 نیاز دارید، VPS یا سرور اختصاصی گزینه مناسب‌تری است.
