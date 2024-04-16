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

      var searchString = $('#entry-affected_input_name-search').val();
      var SearchHasFocus = $('#entry-affected_input_name-search').is(':focus')

      $.ajax({
        url: window.location.pathname + window.location.search,
        dataType: 'script',
      }).done(function () {
        $(opened).each( function (){ $('#' + this).toggle() } );
        $('#entry-affected_input_name-search').val(searchString);
        window.entryNameSearch( searchString );

        $('#entry-affected_input_name-search').keyup( function () {
          window.entryNameSearch( $(this).val() );
        });

        if( SearchHasFocus ) {
          $('#entry-affected_input_name-search').focus();
        }
      })
    }
  });
});
