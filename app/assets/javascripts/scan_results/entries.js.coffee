entryNameSearch = ( string ) ->
  $('.entry-affected_input_name code').each ->
    if string == "" || string == undefined
      $(this).closest('tr.entry-row').show()
      return

    if $(this).html().includes( string )
      $(this).closest('tr.entry-row').show()
    else
      $(this).closest('tr.entry-row').hide()

window.entryNameSearch = entryNameSearch

setup = () ->
  $('#entry-affected_input_name-search').keyup ->
    entryNameSearch( $(this).val() )

jQuery setup
$(document).on( "turbo:load", setup )
