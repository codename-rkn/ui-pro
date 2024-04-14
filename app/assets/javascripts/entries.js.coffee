setup = ->
    scrollToChild( '.highlight-container', '.highlight' )

    $('form#state-form select#entry_state').on 'change', ->
        $('form#state-form').submit()

    $('input.entry-state').on 'change', ->
        $(this).closest('form').submit()

jQuery ->
    setup()

$(document).on( "turbo:load", setup );
