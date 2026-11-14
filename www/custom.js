/* FuelBot Lite · interacciones del chat y desplazamiento de la conversación */
(function () {
  function alFinal() {
    document.querySelectorAll('.fb-chat__scroll').forEach(function (el) {
      el.scrollTop = el.scrollHeight;
    });
  }

  function observarChats() {
    document.querySelectorAll('.fb-chat__scroll').forEach(function (el) {
      if (el.dataset.fbObserved === '1') return;
      el.dataset.fbObserved = '1';
      new MutationObserver(function () {
        el.scrollTop = el.scrollHeight;
      }).observe(el, { childList: true, subtree: true });
    });
  }

  function terminarChat($chat) {
    $chat.find('.typing').addClass('hidden');
    $chat.find('.fb-send').prop('disabled', false);
  }

  function enlazar() {
    if (!window.jQuery || !window.Shiny || window.__fbChatBound === true) return;
    window.__fbChatBound = true;

    $(document).on('click', '.fb-send', function () {
      var $chat = $(this).closest('.fb-chat');
      if (!$.trim($chat.find('textarea').val())) return;
      $chat.find('.typing').removeClass('hidden');
      $chat.find('.fb-send').prop('disabled', true);
    });

    $(document).on('keydown', '.fb-chat textarea', function (e) {
      if ((e.ctrlKey || e.metaKey) && e.key === 'Enter') {
        e.preventDefault();
        $(this).closest('.fb-chat').find('.fb-send').trigger('click');
      }
    });

    $(document).on('shiny:value shiny:error', function (e) {
      if (e.target && e.target.id === 'agente-chat') {
        terminarChat($(e.target).closest('.fb-chat'));
      }
    });

    Shiny.addCustomMessageHandler('fb_fin', function (msg) {
      terminarChat($('.fb-chat'));
    });

    Shiny.addCustomMessageHandler('fb_scroll', function (msg) {
      window.setTimeout(alFinal, 120);
    });
  }

  function iniciar() {
    enlazar();
    observarChats();
    new MutationObserver(observarChats).observe(document.body, { childList: true, subtree: true });
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', iniciar);
  } else {
    iniciar();
  }
})();
