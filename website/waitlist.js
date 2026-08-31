(function () {
  var STORAGE_KEY = 'wajib_waitlist_emails';

  function saveLocally(email) {
    try {
      var list = JSON.parse(localStorage.getItem(STORAGE_KEY) || '[]');
      if (list.indexOf(email) === -1) list.push(email);
      localStorage.setItem(STORAGE_KEY, JSON.stringify(list));
    } catch (e) {
      /* localStorage unavailable — ignore, submission still attempted via Formspree */
    }
  }

  function setMessage(form, text) {
    var msg = form.querySelector('.form-msg');
    var fields = form.querySelector('.form-fields');
    msg.textContent = text;
    msg.hidden = false;
    fields.hidden = true;
  }

  document.addEventListener('DOMContentLoaded', function () {
    var form = document.getElementById('waitlist-form');
    if (!form) return;

    form.addEventListener('submit', function (event) {
      event.preventDefault();
      var input = form.querySelector('input[name="email"]');
      var email = input.value.trim();
      if (!email) return;

      var button = form.querySelector('button[type="submit"]');
      var endpoint = form.getAttribute('data-formspree-endpoint');
      var configured = endpoint && endpoint.indexOf('YOUR_FORM_ID') === -1;

      saveLocally(email);
      button.disabled = true;

      if (!configured) {
        // No email backend configured yet — see website/README.md to activate Formspree.
        setMessage(form, 'تم حفظ بريدك على هذا الجهاز! لتفعيل الإرسال الفعلي راجع website/README.md');
        return;
      }

      fetch(endpoint, {
        method: 'POST',
        headers: { Accept: 'application/json', 'Content-Type': 'application/json' },
        body: JSON.stringify({ email: email })
      })
        .then(function (response) {
          if (response.ok) {
            setMessage(form, 'شكراً لك! سنتواصل معك قريباً. 🎉');
          } else {
            setMessage(form, 'تعذّر الإرسال الآن، لكن تم حفظ بريدك محلياً — حاول لاحقاً.');
          }
        })
        .catch(function () {
          setMessage(form, 'تعذّر الإرسال الآن، لكن تم حفظ بريدك محلياً — حاول لاحقاً.');
        });
    });
  });
})();
