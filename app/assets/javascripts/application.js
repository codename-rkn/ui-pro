// This is a manifest file that'll be compiled into application.js, which will include all the files
// listed below.
//
// Any JavaScript/Coffee file within this directory, lib/assets/javascripts, vendor/assets/javascripts,
// or vendor/assets/javascripts of plugins, if any, can be referenced here using a relative path.
//
// It's not advisable to add code directly here, but if you do, it'll appear at the bottom of the
// compiled file.
//
// Read Sprockets README (https://github.com/sstephenson/sprockets#sprockets-directives) for details
// about supported directives.
//
//= require jquery
//= require popper
//= require bootstrap-sprockets
//= require d3
//= require ace/ace
//= require ace/worker-html
//= require ace/theme-monokai
//= require ace/mode-ruby
//= require_tree .

function loading(){
    $('#loading').show();
}

function loaded(){
    $('#loading').hide();
}

jQuery.fn.reverse = [].reverse;
jQuery.fn.exists = function(){ return this.length > 0; };

$.expr[':'].icontains = function(obj, index, meta, stack){
    return (obj.textContent || obj.innerText || jQuery(obj).text() || '').
        toLowerCase().indexOf(meta[3].toLowerCase()) >= 0;
};

String.prototype.endsWith = function(suffix) {
    return this.indexOf(suffix, this.length - suffix.length) !== -1;
};

String.prototype.toHHMMSS = function () {
    var sec_num = parseInt(this, 10);
    var hours   = Math.floor(sec_num / 3600);
    var minutes = Math.floor((sec_num - (hours * 3600)) / 60);
    var seconds = sec_num - (hours * 3600) - (minutes * 60);

    if (hours   < 10) {hours   = "0"+hours;}
    if (minutes < 10) {minutes = "0"+minutes;}
    if (seconds < 10) {seconds = "0"+seconds;}
    var time    = hours+':'+minutes+':'+seconds;
    return time;
};

window.topOffset = undefined;

function ace_editor( id ) {
    var editor = ace.edit( id );
    editor.setTheme( 'ace/theme/monokai' );
    editor.getSession().setMode( 'ace/mode/ruby' );
    editor.setShowPrintMargin(false);
    editor.getSession().setUseSoftTabs( true );
    editor.getSession().setUseWrapMode( true );
    return editor;
}

function goTo( location ){
    // Restore the last open tab from the URL fragment.
    if( !location || location.length <= 0 ) return;

    var target = $('#' + location.replace( /\//g, '-' ));

    var nodes = target.parents();
    nodes.reverse();
    nodes.push( target );

    nodes.each(function() {
        var level = $(this);

        var id = level.attr('id');

        if( !id ) return;

        // Mark all other tabs of this level as inactive...
        level.siblings().removeClass('active');
        //.. and activate the one we want.
        level.addClass('active');
        // In case it's hidden.
        level.show();

        var tab_selector;
        if( !(tab_selector = $('a[href="#!/' + id + '"]')).exists() ) {
            if( !(tab_selector = $('a[href="#!/' + id.replace( /-/g, '/' ) + '"]')).exists() ) {
                return;
            }
        }

        // Mark all links in the navigation tree as active at every step.
        tab_selector.parents('li').siblings().removeClass('active');
        tab_selector.parents('li').addClass('active');


        // In case it's a collapsible.
        if( level.hasClass('collapse') ) {
            level.addClass('in');
        }

        target = level;
    });

    if( !target.length ) return;
    if( !target.hasClass('tab-pane') ) {
        $('html,body').scrollTop( target.offset().top - window.topOffset );
    }
}

function goToLocation( location ){
    window.location.hash = '#!/' + location;
}

function openFromWindowLocation(){
    goTo( window.location.hash.split('#!/')[1] );
}

function idFromWindowLocation() {
    var loc = window.location.hash.split( '#!/' )[1];
    if( !loc ) return;

    return loc.replace( /\//g, '-' )
}

function scrollToActiveElementFromWindowLocation() {
    var element = $('#' + idFromWindowLocation());
    if( !element.length ) return;

    $('html,body').scrollTop( element.offset().top - window.topOffset );
}

// Parent must have 'position: relative;'
function scrollToChild( parent_selector, child_selector ){
    var parent = $(parent_selector);

    if( !parent.exists() ) return;

    parent.each( function(){
        var current_parent = $(this);

        var child = current_parent.children( child_selector );

        if( !child.exists() ) return;

        current_parent.scrollTop(
            current_parent.scrollTop() + child.position().top -
            (current_parent.height() / 2) + (child.height())
        );
    });

}

function setupScroll(){
    if( $('#scrollspy-container').is(':visible' ) ) {
        const scrollSpy = new bootstrap.Scrollspy(document.body, {
            target: '#scrollspy-container',
            offset: window.topOffset + 20,
            smoothScroll: true
        });

        scrollSpy.refresh();
    };
}

// window.original_confirm = window.confirm;
// Turbo.FormSubmission.confirmMethod = function( data, title, cb ){
//     window.disablePageUpdate = true;
//     console.log( 1 );
//     ret = window.original_confirm.apply( window, [data, title, cb] );
//     // window.disablePageUpdate = false;
//     return ret
// }

function setup() {
    window.topOffset = $('#top-nav').height();

    // Init all tooltips.
    // https://github.com/twbs/bootstrap/entries/35710#entrycomment-1030352173
    let tooltipTriggerList = [].slice.call(document.querySelectorAll('[data-bs-toggle="tooltip"]'));

    tooltipTriggerList.forEach(function (element) {
        bootstrap.Tooltip.getOrCreateInstance(element);
    });

    $('a[data-bs-toggle="tab"]').on('shown.bs.tab', setupScroll);

    setupScroll();

    // Restore the last open tab from the URL fragment.
    openFromWindowLocation();
    scrollToActiveElementFromWindowLocation();

    // Keep the revision duration timer going.
    var previous_interval = window.clock_interval;
    window.clock_interval = setInterval(
        function (){
            if( !window.scan_duration_seconds ) {
                clearInterval(previous_interval);
                return;
            }

            var scan_duration_hms = new Date( window.scan_duration_seconds * 1000 ).toISOString().slice( 11, 19 );
            // console.log( scan_duration_hms );
            $('.scan-duration-clock-hms').html( scan_duration_hms );
            window.scan_duration_seconds += 1;

            if( previous_interval )
                clearInterval( previous_interval ) ;
        },
        1000
    );
}

$(window).bind( 'hashchange', function () {
    openFromWindowLocation();
});

$(document).on( "turbo:load", setup );
