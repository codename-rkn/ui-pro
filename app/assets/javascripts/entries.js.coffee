setup = ->
    scrollToChild( '.highlight-container', '.highlight' )

    $('select#entry_state').on 'change', ->
        $('.edit_entry').submit()

    $('input.entry-state').on 'change', ->
        $(this).closest('form').submit()

jQuery ->
    setup()

$(document).on( "turbo:load", setup );
