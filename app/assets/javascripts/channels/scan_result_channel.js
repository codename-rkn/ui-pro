$(document).on('turbo:load', function() {
  const channel = 'ScanResultChannel';

  if (!loadChannel(channel)) {
    return;
  };

  if (alreadySubscribed(channel)) {
    return;
  };

  App.cable.subscriptions.create(channel, {
    received() {
      var opened = [];
      $('tr.entry-notes:visible').each( function () {
        opened.push( $(this).attr('id') );
      });

      $.ajax({
        url: window.location.pathname + window.location.search,
        dataType: 'script',
      }).done(function () {
        $(opened).each( function (){ $('#' + this).toggle() } )
      })
    }
  });
});
