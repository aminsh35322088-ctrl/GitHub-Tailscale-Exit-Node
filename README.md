<div align="center">

# 🌐 GitHub Tailscale Exit Node

**از اولین کلیک تا اتصال گوشی و کامپیوتر**

راهنمای فارسی راه‌اندازی خروجی اینترنت با Tailscale روی GitHub Actions

[شروع راه‌اندازی](#start) · [اتصال دستگاه](#connect) · [توقف و شروع](#controls) · [رفع مشکل](#troubleshooting) · [English](./README.en.md)

</div>

<!-- EXIT-NODE-STATUS:START -->

<div dir="rtl">

## 📡 آخرین وضعیت ثبت‌شده

| مورد | مقدار |
| :--- | :--- |
| وضعیت اجرا | 🟢 نگهداری اتصال در حال اجرا · راه‌اندازی تأیید شده |
| آخرین بررسی | 2026-09-12 23:48:36 UTC |
| نام تنظیم‌شده | `GitHub-Exit` |
| شروع مرحلهٔ نگهداری | 2026-09-12 23:48:24 UTC |
| زمان سپری‌شده تا این بررسی | 0 دقیقه |
| تعویض تقریبی | 2026-09-13 05:18:24 UTC |
| جزئیات اجرا | [مشاهده](https://github.com/aminsh35322088-ctrl/GitHub-Tailscale-Exit-Node/actions/runs/34711196935) |

> این گزارش از مراحل GitHub Actions است، نه تست اینترنت گوشی یا تأیید سلامت لحظه‌ای تونل. به‌روزرسانی هنگام رویداد اجرا و تقریباً هر ۳۰ دقیقه؛ گزارش قدیمی‌تر از ۶۰ دقیقه را نامعتبر بدانید. زمان تعویض تخمینی است و شمارنده فقط در زمان بررسی به‌روز می‌شود.

</div>

<!-- EXIT-NODE-STATUS:END -->

<div dir="rtl">

## قرار است چه چیزی بسازیم؟

این پروژه یک کامپیوتر لینوکسی موقت روی **GitHub Actions** اجرا می‌کند و آن را به شبکهٔ خصوصی Tailscale شما اضافه می‌کند. وقتی آن را در برنامهٔ Tailscale به‌عنوان **Exit Node** انتخاب کنید، ترافیک اینترنت دستگاه شما از آن خارج می‌شود.

برای راه‌اندازی اولیه، نیازی به نصب لینوکس، خرید VPS یا واردکردن دستور در ترمینال ندارید؛ تنظیمات را در مرورگر انجام می‌دهید.

| اصطلاح | معنی ساده |
| :--- | :--- |
| **Fork** | یک کپی از این پروژه در حساب GitHub خودتان |
| **Workflow / Run** | برنامهٔ خودکار GitHub / یک بار اجرای آن |
| **Tailnet** | شبکهٔ خصوصی دستگاه‌های شما در Tailscale |
| **Exit Node** | دستگاهی که اینترنت شما از آن خارج می‌شود |
| **Secret** | محل نگهداری محرمانهٔ کلیدها در GitHub |
| **Watchdog** | برنامه‌ای که اجراها را بررسی و برای راه‌اندازی مجدد تلاش می‌کند |

> [!IMPORTANT]
> این سرویس موقتی است. هر اجرا در تنظیم فعلی حدود **۵ ساعت و نیم** آنلاین می‌ماند و سپس جای خود را به اجرای بعدی می‌دهد. هنگام تعویض ممکن است اتصال قطع شود یا نیاز باشد Exit Node جدید را دوباره انتخاب کنید. IP ثابت، کشور مشخص و اتصال دائمی تضمین نمی‌شود.

<a id="start"></a>

## 🚀 مسیر راه‌اندازی

**۱. کپی پروژه · ۲. تنظیم شبکه · ۳. کلید Tailscale · ۴. کلید GitHub · ۵. ذخیرهٔ کلیدها · ۶. اجرا · ۷. اتصال**

قبل از شروع، این‌ها را آماده داشته باشید:

- حساب [GitHub](https://github.com) با امکان اجرای Actions.
- حساب [Tailscale](https://login.tailscale.com/start) با دسترسی مدیریت شبکه.
- گوشی یا کامپیوتری که می‌خواهید به Exit Node وصل شود.

روی موبایل، اگر دکمه‌های GitHub دیده نمی‌شوند، حالت **Desktop site / سایت دسکتاپ** مرورگر را روشن کنید.

### ۱ · یک کپی برای خودتان بسازید

1. بالای همین صفحه روی **Fork** و سپس **Create a new fork** بزنید.
2. در **Owner** حساب خودتان را انتخاب کنید؛ نام پروژه را می‌توانید نگه دارید.
3. روی **Create fork** بزنید.

**✅ نتیجه:** ابتدای آدرس صفحه باید نام کاربری خودتان باشد. تمام مراحل بعدی GitHub را در همین کپی انجام دهید. Secretهای صاحب پروژه به Fork شما منتقل نمی‌شوند.

### ۲ · شبکهٔ Tailscale را آماده کنید

در [پنل Tailscale](https://login.tailscale.com/admin) وارد شبکهٔ خودتان شوید. سپس [Access controls](https://login.tailscale.com/admin/acls/file) را باز کنید و وارد ویرایشگر متنی **JSON** شوید.

دو تنظیم لازم داریم:

- **`tag:exit`**: برچسب شناسایی دستگاه‌های این پروژه.
- **`autoApprovers`**: تأیید خودکار قابلیت Exit Node، تا با هر اجرای جدید مجبور به تأیید دستی نباشید.

<details>
<summary><strong>🆕 حساب تازه ساخته‌اید؟ نمونهٔ کامل و قابل‌کپی را باز کنید</strong></summary>

اگر این شبکه تازه است و تنظیم یا دستگاه مهم دیگری ندارد، می‌توانید متن زیر را جایگزین Policy اولیه کنید و **Save** بزنید. این نمونه به دستگاه‌های کاربران عضو شبکه اجازهٔ استفاده از اینترنت از طریق Exit Node می‌دهد؛ دسترسی مستقیم بین دستگاه‌ها یا SSH را تعریف نمی‌کند.

<div dir="ltr">

```json
{
  "tagOwners": {
    "tag:exit": ["autogroup:admin"]
  },
  "autoApprovers": {
    "exitNode": ["tag:exit"]
  },
  "grants": [
    {
      "src": ["autogroup:member"],
      "dst": ["autogroup:internet"],
      "ip": ["*"]
    }
  ]
}
```

</div>

</details>

<details>
<summary><strong>🔧 از قبل Tailscale دارید؟ تنظیمات را به Policy فعلی اضافه کنید</strong></summary>

ابتدا یک کپی از Policy فعلی نگه دارید. سپس این موارد را در ساختار موجود ادغام کنید؛ کل فایل را جایگزین نکنید:

1. داخل `tagOwners`، ورودی `"tag:exit": ["autogroup:admin"]` را اضافه کنید.
2. داخل `autoApprovers`، کلید `exitNode` را با مقدار `["tag:exit"]` اضافه کنید؛ اگر لیست از قبل وجود دارد، فقط `tag:exit` را به آن بیفزایید.
3. اگر کاربران مجاز از قبل دسترسی به اینترنت ندارند، یک قانون برای مقصد `autogroup:internet` اضافه کنید. قانون `grants` نمونهٔ بالا همهٔ اعضا را مجاز می‌کند؛ برای شبکهٔ محدود، `src` را مطابق کاربران مجاز خودتان تنظیم کنید.

کلیدهای تکراری مثل دو `tagOwners` نسازید. بین ورودی‌های JSON ویرگول بگذارید و فقط وقتی ویرایشگر خطایی نشان نمی‌دهد، ذخیره کنید. تأیید خودکار خروجی و اجازهٔ استفادهٔ کاربران از آن، دو تنظیم جدا هستند.

</details>

**✅ نتیجه:** Policy ذخیره شده و برچسب `tag:exit` تعریف شده است. [مرجع Policy](https://tailscale.com/docs/reference/syntax/policy-file)

### ۳ · کلید اتصال Tailscale را بسازید

1. در پنل Tailscale، [OAuth clients](https://login.tailscale.com/admin/settings/oauth) را باز کنید.
2. گزینهٔ ساخت **OAuth client** را بزنید و نامی مثل `GitHub Exit Node` بدهید.
3. برای **Auth Keys** دسترسی **Write** را فعال کنید؛ این همان مجوز `auth_keys` است.
4. برچسب **`tag:exit`** را برای آن انتخاب کنید و کلاینت را بسازید.
5. دو مقدار **Client ID** و **Client secret** را برای مرحلهٔ ۵ نگه دارید.

**✅ نتیجه:** یک Client ID و یک Client secret دارید. مقدار Secret را همان موقع بردارید؛ ممکن است دوباره نمایش داده نشود. این روش مطابق [راهنمای رسمی Action](https://github.com/tailscale/github-action/tree/v4) است.

> این پروژه در تنظیم فعلی از **OAuth client** استفاده می‌کند؛ به‌جای این دو مقدار، یک Auth key معمولی وارد نکنید.

### ۴ · کلید کنترل GitHub را بسازید

این کلید به پروژه اجازه می‌دهد اجرای بعدی را شروع کند و هنگام توقف، متغیر خاموشی را تنظیم کند.

1. در **تنظیمات حساب GitHub** وارد [Fine-grained personal access tokens](https://github.com/settings/personal-access-tokens) شوید و **Generate new token** را بزنید.
2. نامی مثل `Exit Node Watchdog` انتخاب کنید و تاریخ انقضا را یادداشت کنید.
3. **Resource owner** را حساب خودتان قرار دهید.
4. در **Repository access** گزینهٔ **Only select repositories** را بزنید و فقط Fork همین پروژه را انتخاب کنید.
5. در **Repository permissions** این دسترسی‌ها را تنظیم کنید:

| مجوز | مقدار | کاربرد |
| :--- | :--- | :--- |
| **Actions** | **Read and write** | مشاهده، شروع و لغو اجراها |
| **Variables** | **Read and write** | تنظیم کلید خاموشی هنگام `stop` |
| **Metadata** | **Read-only** | دسترسی پایه که GitHub خودکار اضافه می‌کند |

6. توکن را بسازید و مقدار آن را برای مرحلهٔ بعد کپی کنید.

**✅ نتیجه:** توکن فقط به Fork شما دسترسی دارد. مجوز **Variables** را جا نیندازید؛ بدون آن، توقف از داخل Watchdog خطا می‌دهد. [مرجع مجوز Variables](https://docs.github.com/en/rest/actions/variables#update-a-repository-variable)

### ۵ · سه مقدار را در جای درست ذخیره کنید

به **Fork خودتان** برگردید و این مسیر را باز کنید:

<div dir="ltr">

**Settings → Secrets and variables → Actions → Secrets → New repository secret**

</div>

برای هر ردیف زیر، جداگانه یک Secret بسازید. ستون اول را دقیقاً در **Name** و مقدار مربوط را در **Secret** قرار دهید؛ سپس **Add secret** را بزنید.

| Name — دقیقاً کپی کنید | Secret — چه مقداری وارد کنید؟ |
| :--- | :--- |
| `TS_OAUTH_CLIENT_ID` | Client ID مرحلهٔ ۳ |
| `TS_OAUTH_SECRET` | Client secret مرحلهٔ ۳ |
| `ACTIONS_WATCHDOG_TOKEN` | توکن GitHub مرحلهٔ ۴ |

**✅ نتیجه:** هر سه نام در فهرست **Repository secrets** دیده می‌شوند. مخفی‌بودن مقدارشان بعد از ذخیره طبیعی است.

> [!TIP]
> برای این سه مقدار از تب **Secrets** استفاده کنید، نه **Variables**. هیچ‌کدام را داخل فایل‌های پروژه، Issue یا عکس عمومی قرار ندهید.

### ۶ · اولین اجرا را روشن کنید

1. تب **Actions** را در Fork خودتان باز کنید. اگر پیام فعال‌سازی Workflowها را دیدید، آن را تأیید کنید.
2. از فهرست، **Tailscale Exit Node Watchdog** را انتخاب کنید.
3. روی **Run workflow** بزنید؛ شاخه را **main** و مقدار **action** را **ensure** بگذارید.
4. دکمهٔ اجرای سبز را بزنید. سپس در فهرست Actions، اجرای **Tailscale Exit Node** را باز کنید.
5. در Job به نام **exit-node**، پیشرفت مراحل را ببینید.

| چیزی که می‌بینید | معنی آن |
| :--- | :--- |
| موفقیت **Connect Tailscale** | اتصال Runner به شبکه انجام شده |
| موفقیت **Verify Exit Node** | برچسب و اعلام قابلیت خروجی بررسی شده |
| ادامهٔ اجرای **Keep Exit Node Alive** | طبیعی است؛ همین مرحله سرویس را روشن نگه می‌دارد |
| **Queued / Pending** | اجرا منتظر Runner یا پایان اجرای قبلی است |

**✅ نتیجه:** در [Machines](https://login.tailscale.com/admin/machines)، دستگاه آنلاین **GitHub-Exit** با برچسب `tag:exit` دیده می‌شود.

**برای اتصال منتظر سبزشدن کل Workflow نمانید.** اجرای سالم تا زمانی که Exit Node روشن است، در وضعیت **In progress** می‌ماند. سبزشدن Watchdog به‌تنهایی هم اتصال اینترنت را ثابت نمی‌کند.

اگر دستگاه آنلاین است ولی Exit Node تأیید نشده، از منوی آن در Machines، **Edit route settings → Use as exit node** را فعال و ذخیره کنید. تنظیم `autoApprovers` مرحلهٔ ۲ این تأیید را برای اجراهای بعدی خودکار می‌کند.

<a id="connect"></a>

## 📱 ۷ · گوشی یا کامپیوتر را وصل کنید

برنامه را از [دانلود رسمی Tailscale](https://tailscale.com/download) نصب کنید و با حساب همان شبکه وارد شوید.

| دستگاه | مراحل اتصال |
| :--- | :--- |
| **Android / iPhone** | برنامه را باز کنید، اتصال Tailscale را روشن کنید، بخش **Exit Node** را باز و **GitHub-Exit** آنلاین را انتخاب کنید. درخواست سیستم برای اتصال VPN را تأیید کنید. |
| **Windows** | از آیکن Tailscale کنار ساعت وارد شوید؛ در **Exit node**، دستگاه **GitHub-Exit** آنلاین را انتخاب کنید. |
| **macOS** | از آیکن Tailscale در نوار منو، بخش **Exit Node** را باز و دستگاه آنلاین را انتخاب کنید. |

گزینهٔ **Allow LAN access** برای زمانی است که می‌خواهید هم‌زمان به دستگاه‌های شبکهٔ محلی، مثل مودم یا چاپگر، دسترسی داشته باشید. برای اتصال اولیه لازم نیست آن را روشن کنید. [راهنمای رسمی اتصال](https://tailscale.com/docs/features/exit-nodes)

### از کجا بفهمم کار می‌کند؟

1. قبل از انتخاب Exit Node، IP عمومی را در یک سایت نمایش IP یادداشت کنید.
2. **GitHub-Exit** را انتخاب کنید و همان صفحه را دوباره بارگذاری کنید.
3. تغییر IP عمومی و بازشدن سایت‌ها را بررسی کنید؛ هم‌زمان نام Exit Node انتخاب‌شده باید در برنامه دیده شود.

**✅ پایان راه‌اندازی:** دستگاه آنلاین است، Exit Node انتخاب شده و اینترنت با IP خروجی جدید کار می‌کند.

<a id="controls"></a>

## ⏯️ استفادهٔ روزمره، توقف و شروع دوباره

| کاری که می‌خواهید انجام دهید | روش |
| :--- | :--- |
| فقط گوشی یا کامپیوتر خودم قطع شود | در برنامه، Exit Node را روی **None / Do not use exit node** بگذارید؛ اجرای GitHub ادامه دارد. |
| سرویس را متوقف کنم | **Actions → Tailscale Exit Node Watchdog → Run workflow → action: stop** |
| دوباره روشن کنم | در مسیر زیر، `EXIT_NODE_DISABLED` را حذف کنید یا مقدارش را `false` بگذارید؛ سپس Watchdog را با **ensure** اجرا کنید. |
| وضعیت را بررسی کنم | اجرای **Tailscale Exit Node** و دستگاه آنلاین در پنل Tailscale را بررسی کنید. |

مسیر متغیر خاموشی:

<div dir="ltr">

**Settings → Secrets and variables → Actions → Variables → Repository variables**

</div>

توقف `stop` ابتدا `EXIT_NODE_DISABLED=true` را ثبت و بعد اجراهای جاری و منتظر را لغو می‌کند. **Cancel workflow به‌تنهایی توقف دائمی نیست**؛ بازیابی خودکار ممکن است اجرای دیگری بسازد.

> [!IMPORTANT]
> در نسخهٔ فعلی، متغیر خاموشی در منطق راه‌اندازی مجدد بررسی می‌شود؛ شروع مستقیم یا زمان‌بندی‌شدهٔ Workflow اصلی به‌طور کامل با آن مسدود نشده است. برای **خاموشی کامل تا اطلاع بعدی**، پس از `stop`، هر دو Workflow با نام‌های **Tailscale Exit Node** و **Tailscale Exit Node Watchdog** را از منوی سه‌نقطهٔ صفحهٔ هر Workflow با **Disable workflow** غیرفعال کنید. سپس اجراهای باقی‌ماندهٔ **In progress / Queued** را لغو کنید. برای بازگشت، هر دو را فعال، متغیر را `false` و Watchdog را با `ensure` اجرا کنید.

## 📡 گزارش بالای README چطور کار می‌کند؟

ورک‌فلوی مستقل **README Status** وضعیت Run و مرحله‌ها را از GitHub می‌خواند و بخش مشخص‌شدهٔ هر سه README را هنگام رویداد اجرا و تقریباً هر **۳۰ دقیقه** به‌روز می‌کند. از تب Actions هم می‌توانید آن را دستی اجرا کنید.

سبز یعنی در زمان ثبت گزارش، **Verify Exit Node** موفق بوده و **Keep Exit Node Alive** در حال اجرا بوده است؛ این گزارش تست اینترنت گوشی، تأیید مجوز خروجی یا بررسی لحظه‌ای سلامت تونل نیست. گزارش قدیمی‌تر از **۶۰ دقیقه** را نامعتبر بدانید؛ زمان‌بندی GitHub و نمایش صفحه ممکن است تأخیر داشته باشند.

نام تنظیم‌شده، شروع نگهداری، زمان سپری‌شده در لحظهٔ بررسی، تعویض تقریبی و لینک اجرا نمایش داده می‌شوند. کلیدها، IPها و فهرست دستگاه‌ها منتشر نمی‌شوند. گزارش‌گیر از `GITHUB_TOKEN` داخلی با **Actions: read** و **Contents: write** استفاده می‌کند؛ Secret یا دسترسی جدیدی برای PAT لازم نیست. اگر قوانین شاخه جلوی ویرایش مستقیم را بگیرند، جزئیات خطا در **README Status** دیده می‌شود. غیرفعال‌کردن آن فقط گزارش README را متوقف می‌کند.

<a id="troubleshooting"></a>

## 🧩 اگر جایی گیر کردید

اول اجرای مشکل‌دار را در **Actions** باز کنید، وارد Job شوید و اولین مرحلهٔ قرمز را بخوانید.

| مشکل یا پیام | چه چیزی را بررسی کنید؟ |
| :--- | :--- |
| دکمهٔ **Run workflow** نیست | در Fork خودتان هستید؟ Actions فعال است؟ Workflow را از فهرست انتخاب کرده‌اید؟ روی موبایل حالت دسکتاپ را امتحان کنید. |
| خطا در **Connect Tailscale** | دو Secret مربوط به OAuth، مجوز **Auth Keys: Write** و انتخاب `tag:exit` را بررسی کنید. |
| `tags ... invalid or not permitted` | برچسب باید هم در Policy و هم در مجوز OAuth دقیقاً `tag:exit` باشد. |
| خطای `401` یا `403` در Watchdog | انقضا، دسترسی به Fork و مجوز **Actions: Read and write** توکن GitHub را بررسی کنید. |
| خطای تنظیم `EXIT_NODE_DISABLED` | توکن به **Variables: Read and write** هم نیاز دارد. برای خاموشی کامل، روش بالا را انجام دهید. |
| Watchdog سبز است ولی اجرای جدید ندارم | مقدار `EXIT_NODE_DISABLED`، اجراهای موجود در صف و پیام‌های **Ensure an Exit Node Is Running** را بررسی کنید. |
| `Refusing to dispatch to avoid a crash loop` | سه اجرای کوتاهِ ناموفق باعث توقف بازیابی شده‌اند. ابتدا علت خطا را رفع کنید؛ سپس Workflow اصلی **Tailscale Exit Node** را یک بار دستی اجرا کنید. |
| دستگاه هست ولی در فهرست Exit Node نیست | تأیید خروجی در Machines، `autoApprovers` و اجازهٔ کاربر به `autogroup:internet` را بررسی کنید. |
| وصل می‌شوم ولی سایت‌ها باز نمی‌شوند | آنلاین‌بودن خروجی و Policy را بررسی کنید؛ برای تست، VPN دیگری را که ممکن است با Tailscale تداخل داشته باشد خاموش کنید و یک شبکهٔ دیگر را امتحان کنید. |
| بعد از چند ساعت قطع می‌شود | اجرای جدید و دستگاه آنلاین تازه را پیدا کنید؛ در صورت نیاز Exit Node را دوباره انتخاب کنید. نام یکسان به معنی هویت ثابت دستگاه نیست. |
| گزارش README قدیمی یا نامشخص است | لاگ **README Status** را برای خطای API یا ثبت تغییرات بررسی کنید؛ خطای گزارش‌گیری لزوماً به معنی قطع خروجی نیست. |
| سرعت پایین است | مسیر بین اینترنت شما و Runner تعیین‌کننده است؛ اتصال Relay ممکن است کندتر باشد. این پروژه اتصال Direct را تضمین نمی‌کند. |

<details>
<summary><strong>🖥️ بررسی Direct یا Relay روی کامپیوتر — اختیاری</strong></summary>

اگر دستور `tailscale` روی کامپیوترتان در دسترس است، دستور زیر را با IP خود دستگاه **GitHub-Exit** که در Machines دیده می‌شود اجرا کنید؛ IP نمونه را جایگزین کنید:

<div dir="ltr">

```bash
tailscale ping 100.x.y.z
```

</div>

در خروجی، `via DERP(...)` نشان‌دهندهٔ مسیر رله و `via IP:port` نشان‌دهندهٔ مسیر مستقیم است. ممکن است پاسخ‌های اول رله باشند و سپس مسیر مستقیم برقرار شود. این تست مسیر Tailscale را بررسی می‌کند؛ برای اینترنت، تست IP و بازکردن سایت را هم انجام دهید.

</details>

## ⚙️ پشت صحنه، به زبان ساده

| بخش | رفتار در کد فعلی |
| :--- | :--- |
| **Exit Node** | روی `ubuntu-latest` اجرا می‌شود؛ نام درخواستی `GitHub-Exit` و زمان نگهداری ۳۳۰ دقیقه است. |
| **تعویض اجرا** | اجرای بعدی را در صف قرار می‌دهد؛ به‌دلیل اجرای ترتیبی، شروع Runner جدید می‌تواند فاصلهٔ اتصال ایجاد کند. |
| **Watchdog** | بعد از پایان Workflow اصلی و با برنامهٔ زمانی هر ۱۰ دقیقه بررسی می‌کند؛ زمان‌بندی GitHub ممکن است تأخیر داشته باشد. |
| **اجرای پشتیبان** | Workflow اصلی در دقیقهٔ ۱۷، هر ۶ ساعت نیز زمان‌بندی شده است. |
| **محافظ خطا** | در حالت نبود اجرای فعال یا منتظر، سه شکست متوالی زیر ۱۵ دقیقه مانع شروع خودکار بعدی می‌شود. |
| **README Status** | گزارش مستقل مراحل اجرا، بدون دخالت در اتصال یا بازیابی |
| **Repository Heartbeat** | هفته‌ای یک‌بار بررسی می‌کند؛ اگر ۳۰ روز از آخرین Commit گذشته باشد، فایل heartbeat را به‌روزرسانی و Commit می‌کند. |

<details>
<summary><strong>📂 فایل‌های پروژه و بررسی فنی</strong></summary>

| فایل | کاربرد |
| :--- | :--- |
| [tailscale-exit-node.yml](./.github/workflows/tailscale-exit-node.yml) | ساخت خروجی، بررسی اتصال و آماده‌کردن اجرای بعدی |
| [tailscale-watchdog.yml](./.github/workflows/tailscale-watchdog.yml) | فرمان‌های `ensure` و `stop` و گزارش اجراها |
| [ensure-exit-node.sh](./.github/scripts/ensure-exit-node.sh) | بررسی اجراهای فعال، صف و بازیابی |
| [repository-heartbeat.yml](./.github/workflows/repository-heartbeat.yml) | ثبت فعالیت دوره‌ای مخزن |
| [readme-status.yml](./.github/workflows/readme-status.yml) | گزارش‌گیر مستقل وضعیت README |
| [readme-status.py](./.github/scripts/readme-status.py) | خواندن وضعیت و به‌روزرسانی بخش گزارش |
| [ensure-exit-node.test.sh](./.github/scripts/tests/ensure-exit-node.test.sh) | تست‌های محلی منطق بازیابی با ابزارهای شبیه‌سازی‌شده |

برای اجرای تست موجود، در ریشهٔ کپی محلی پروژه و محیط دارای Bash و jq:

<div dir="ltr">

```bash
bash .github/scripts/tests/ensure-exit-node.test.sh
```

</div>

Workflow، Tailscale SSH را هم روشن می‌کند؛ استفاده از SSH به قانون دسترسی مربوط نیاز دارد و برای اتصال اینترنت این آموزش لازم نیست.

</details>

## 📌 محدودیت‌ها و نگهداری

- **بودجه و شرایط سرویس:** وضعیت سهمیه و صورتحساب Actions حساب خودتان و [شرایط استفادهٔ GitHub](https://docs.github.com/en/site-policy/github-terms/github-terms-for-additional-products-and-features#actions) را بررسی کنید؛ این راهنما وعدهٔ سرور رایگان دائمی نمی‌دهد.
- **تاریخ انقضای توکن:** پیش از انقضای PAT، توکن جدید بسازید و مقدار `ACTIONS_WATCHDOG_TOKEN` را به‌روزرسانی کنید.
- **دستگاه موقت:** Action در هر اجرا دستگاه موقت می‌سازد؛ ثابت‌بودن نام، IP یا اتصال بدون وقفه را تضمین نمی‌کند.
- **IPv6:** کد، Forwarding هر دو نسخهٔ IP را فعال می‌کند؛ خروجی عمومی IPv6 به شبکهٔ Runner بستگی دارد.
- **Tailnet Lock:** این آموزش برای تنظیم فعلی OAuth است؛ شبکه‌های دارای Tailnet Lock به [تنظیم متفاوت Action](https://github.com/tailscale/github-action/tree/v4#tailnet-lock) نیاز دارند.
- **افشای کلید:** کلید لو‌رفته را در سرویس صادرکننده باطل و جایگزین کنید؛ پاک‌کردن آن از یک فایل، به‌تنهایی کافی نیست.

---

**منابع بیشتر:** [OAuth در Tailscale](https://tailscale.com/docs/features/oauth-clients) · [Exit Nodes](https://tailscale.com/docs/features/exit-nodes) · [ساخت PAT](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens) · [محدودیت‌های Actions](https://docs.github.com/en/actions/reference/limits)

[⬆ بازگشت به مراحل راه‌اندازی](#start)

</div>
