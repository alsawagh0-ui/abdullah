# موقع واجِب | WAJIB

موقع تعريفي ثابت (Landing Page) لمشروع واجِب، بلغة عربية واتجاه RTL.

## التشغيل محلياً

لا حاجة لأي بناء أو تثبيت حزم — الموقع HTML/CSS ثابت بالكامل.

```bash
cd website
python3 -m http.server 8000
```

ثم افتح `http://localhost:8000`.

## النشر

يمكن نشر المجلد مباشرة على أي استضافة ثابتة (GitHub Pages، Netlify، Vercel، Cloudflare Pages) دون أي إعدادات إضافية.

## تفعيل نموذج قائمة الانتظار

نموذج قائمة الانتظار (`#waitlist-form`) يحفظ البريد محلياً في المتصفح دائماً كنسخة احتياطية،
ويحاول أيضاً إرساله إلى خدمة خارجية عبر [Formspree](https://formspree.io) — مجانية ولا تحتاج بطاقة ائتمان.

لتفعيل الإرسال الفعلي:

1. أنشئ حساباً مجانياً على formspree.io واحصل على رابط نموذج مثل
   `https://formspree.io/f/xxxxabcd`.
2. افتح `index.html` وابحث عن `data-formspree-endpoint="https://formspree.io/f/YOUR_FORM_ID"`
   في وسم `<form id="waitlist-form">`، واستبدل `YOUR_FORM_ID` برقم نموذجك.
3. انشر الموقع من جديد — كل تسجيل سيصلك على بريدك الإلكتروني تلقائياً.

قبل هذا الإعداد يعمل النموذج بشكل طبيعي ويعرض رسالة توضح أن البريد
حُفظ محلياً فقط (`localStorage`، المفتاح `wajib_waitlist_emails`) دون إرسال فعلي.
