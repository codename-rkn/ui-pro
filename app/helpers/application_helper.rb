module ApplicationHelper

    def select_button_class( path, include_actions: [], include_children: true )
        default  = 'btn btn-sm btn-light'
        selected = 'btn btn-sm btn-primary'

        if include_actions.any?
            include_actions.each do |action|
                return selected if request.env['PATH_INFO'].to_s.starts_with?( "#{path}/#{action}" )
            end
        else
            return request.env['PATH_INFO'].to_s.start_with?( path ) ? selected : default
        end

        request.env['PATH_INFO'].to_s ==  path ? selected : default
    end

    def seconds_to_hms( seconds )
        SCNR::Engine::Utilities.seconds_to_hms seconds
    end

    def refreshable_partial( resource, options = {} )
        options[:path]    = refreshable_partial_channel_path( resource )
        options[:partial] = refreshable_partial_path( resource, options )

        options[:tagname] ||= 'div'
        options[:id]      ||= options[:path][1..-1].gsub( '/', '_' )
        options[:classes] ||= nil

        render partial: 'shared/refreshable_partial', locals: options
    end

    def refresh_partial( resource, options = {} )
        current_user.notify_browser(
            refreshable_partial_channel( resource ),
            render_to_string( partial: refreshable_partial_path( resource, options ) )
        )
    end

    def refreshable_partial_channel( resource )
        "refreshable-partial://#{refreshable_partial_channel_path( resource )}"
    end

    def refreshable_partial_channel_path( resource )
        resource = refreshable_partial_prepare_resource( resource )

        partial  = resource.shift
        path     = '/'

        resource.each do |segment|
            case segment
                when ActiveRecord::Base
                    path << "#{segment.class.to_s.tableize}/#{segment.id}/"

                else
                    path << "#{segment}/"
            end
        end

        "#{path}#{partial}"
    end

    def refreshable_partial_path( resource, options = {} )
        resource = refreshable_partial_prepare_resource( resource )

        views = resource.last.is_a?( ActiveRecord::Base ) ?
            resource.last.class.to_s.tableize : resource.last.to_s

        partial = "#{views}/#{resource.first}"
        partial << ".#{options[:format]}" if options[:format]
        partial
    end

    def refreshable_partial_prepare_resource( resource )
        resource = [resource].flatten
        return resource.dup if resource.size > 1
        [resource, params[:controller]].flatten
    end

    def url_without_scheme_host_port( url )
        url = url.dup

        parsed = SCNR::Engine::URI( url )
        scheme_host_and_port = "#{parsed.scheme}://#{parsed.host}"
        scheme_host_and_port << ":#{parsed.port}" if parsed.port

        url.sub!( scheme_host_and_port, '' )
        return '/' if url.empty?

        url
    end

    def link_to_url_with_external( options = {} )
        if options.delete(:display_path_only)
            options[:display] = url_without_scheme_host_port( options[:external] )
        end

        render partial: 'shared/link_to_url_with_external', locals: {
            options:      options
        }
    end

    def link_to_external( url )
        render partial: 'shared/link_to_external', locals: {
            url: url
        }
    end

    def md( markdown )
        return if !markdown

        html = Kramdown::Document.new( markdown ).to_html.recode
        Loofah.fragment( html ).scrub!(:prune).to_s.html_safe
    end

    def advanced( options = {}, &block )
        render layout: 'shared/advanced', locals: options, &block
    end

    def code_highlight( *args, &block )
        if block_given?
            code  = capture( &block )
        else
            code = args.shift
        end

        language, options = *args
        language ||= :html
        options  ||= {}

        return if !code

        code = code.strip

        lines = CodeRay.scan( code.recode, language ).html.lines.to_a

        if options[:from]
            from = [0, options[:from]].max
        else
            from = 0
        end

        if options[:to]
            to = [lines.size, options[:to]].min
        else
            to = lines.size - 1
        end

        code = '<div class="code-container"><table class="CodeRay"><tbody><tr>'

        if options[:line_numbers]
            code << '<td class="line-numbers"><pre>'
            from.upto(to) do |i|
                if options[:anchor_id]
                    line = "<a href='#{id_to_location "#{options[:anchor_id]}-#{i}"}'>#{i}</a>"
                else
                    line = "#{i}"
                end

                if options[:breakpoint] && options[:breakpoint] == i
                    code << "<span class='breakpoint'>#{line}</span>"
                else
                    code << line
                end

                code << "\n"
            end

            code << '</pre></td>'
        end

        code << "<td class=\"code #{options[:line_numbers] ? 'with' : 'without' }-line-numbers\"><pre>"

        from.upto(to) do |i|
            line = "<span id='#{options[:anchor_id]}-#{i}'>#{lines[i]}</span>"

            if options[:breakpoint] && options[:breakpoint] == i
                code << "<span class='breakpoint'>#{line}</span>"
            else
                code << line.to_s
            end
        end

        (code + '</pre></td></tr></tbody></table></div>').html_safe
    end

    extend self
end
