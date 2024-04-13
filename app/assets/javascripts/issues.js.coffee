setup = ->
    scrollToChild( '.highlight-container', '.highlight' )
    $('select#entry_state').on 'change', ->
        $('.edit_entry').submit()

jQuery ->
    setup()

$(document).on( "turbo:load", setup );
