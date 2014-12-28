module Asciidoctor
  # A built-in {Converter} implementation that generates Mallard output, a
  # format that is used for GNOME help documents.
  #
  # Based off the AsciiDoc Mallard backend from
  # https://github.com/zykh/mallard-backend/
  class Converter::MallardConverter < Converter::BuiltIn
    def document node
      result = []
      result << '<?xml version="1.0" encoding="UTF-8"?>'
      if node.attr? 'toc'
        if node.attr? 'toclevels'
          result << %(<?asciidoc-toc maxdepth="#{node.attr 'toclevels'}"?>)
        else
          result << '<?asciidoc-toc?>'
        end
      end
      # FIXME: add ID to node.
      lang_attribute = (node.attr? 'nolang') ? nil : %( #{lang_attribute_name}="#{node.attr 'lang', 'en'}")
      result << %(<page#{document_ns_attributes node}#{lang_attribute}>)
      result << (document_info_element node)
      result << node.content if node.blocks?
      unless (footer_docinfo = node.docinfo :footer).empty?
        result << footer_docinfo
      end
      result << %(</page>)

      result * EOL
    end

    alias :embedded :content

    def section node
      %(<section#{common_attributes node, true}>
<title>#{node.title}</title>
#{node.content}
</section>)
    end

    def admonition node
      %(<note style="#{node.attr 'name'}"#{common_attributes node}>
#{title_tag node}#{resolve_content node}
</note>)
    end

    alias :audio :skip
    alias :colist :skip

    DLIST_TAGS = {
      'labeled' => {
        :list  => 'terms',
        :entry => 'item',
        :term  => 'title',
      },
      'qanda' => {
        :list  => 'list',
        :entry => 'item',
        :label => nil,
        :term  => 'p',
      },
      'glossary' => {
        :list  => 'terms',
        :entry => 'item',
        :term  => 'title',
      },
      'horizontal' => {
        :list  => 'terms',
        :entry => 'item',
        :term  => 'title'
      }
    }
    DLIST_TAGS.default = DLIST_TAGS['labeled']

    def dlist node
      result = []
      tags = DLIST_TAGS[node.style]
      list_tag = tags[:list]
      entry_tag = tags[:entry]
      label_tag = tags[:label]
      term_tag = tags[:term]
      if list_tag
        result << %(<#{list_tag}#{common_attributes node}>)
        # FIXME: does this work correctly?
        result << %(<title>#{node.title}</title>) if node.title?
      end

      node.items.each do |terms, dd|
        result << %(<#{entry_tag}>)
        result << %(<#{label_tag}>) if label_tag

        [*terms].each do |dt|
          result << %(<#{term_tag}>#{dt.text}</#{term_tag}>)
        end

        result << %(</#{label_tag}>) if label_tag
        unless dd.nil?
          result << %(<p>#{dd.text}</p>) if dd.text?
          result << dd.content if dd.blocks?
        end
        result << %(</#{entry_tag}>)
      end

      result << %(</#{list_tag}>) if list_tag

      result * EOL
    end

    def example node
      %(<example#{common_attributes node}>
#{resolve_content node}
</example>)
    end

    alias :floating_title :skip

    def image node, block_alt = true
      width_attribute = (node.attr? 'width') ? %( width="#{node.attr 'width'}") : nil
      depth_attribute = (node.attr? 'height') ? %( height="#{node.attr 'height'}") : nil

      alt = block_alt ? %(<p>#{node.attr 'alt'}</p>) : (node.attr 'alt')

      mediaobject = %(<media type="image" src="#{node.image_uri(node.attr 'target')}"#{width_attribute}#{depth_attribute}/>
#{alt}
</media>)

      if node.title?
        %(<figure#{common_attributes node}>
<title>#{node.title}</title>
#{mediaobject}
</figure>)
      else
        mediaobject
      end
    end

    def listing node
      if node.style == 'source' || node.title?
        literal node
      else
        %(<screen>#{node.content}</screen>)
      end
    end

    def literal node
      result = []
      result << %(<listing>)
      result << %(<title>#{node.title}</title>) if node.title?
      result << %(<code>#{node.content}</code>
</listing>)
      result * EOL
    end

    def stem node
      result = []
      result << %(<listing>)
      result << %(<title>#{node.title}</title>) if node.title?
      result << %(<code><![CDATA[#{node.content}]]></code>
</listing>)
      result * EOL
    end

    OLIST_STYLES = {
      'arabic'     => 'numbered',
      'loweralpha' => 'lower-alpha',
      'upperalpha' => 'upper-alpha',
      'lowerroman' => 'lower-roman',
      'upperroman' => 'upper-roman',
    }

    def olist node
      result = []
      style = node.style ? OLIST_STYLE[node.style] : 'numbered'
      type_attribute = %( type="#{style}")
      start_attribute = (node.attr? 'start') ? %( startingnumber="#{node.attr 'start'}") : nil
      result << %(<list#{common_attributes node}#{type_attribute}#{start_attribute}>)
      node.items.each do |item|
        result << '<item>'
        result << %(<p>#{item.text}</p>)
        result << item.content if item.blocks?
        result << '</item>'
      end
      result << %(</list>)
      result * EOL
    end

    def open node
      case node.style
      when 'abstract'
        quote node
      when 'partintro'
        %(<listing#{common_attributes node}>
#{title_tag node}#{resolve_content node}
</listing>)
      else
        node.content
      end
    end

    def page_break node
      '<p><?asciidoc-pagebreak?></p>'
    end

    def paragraph node
      if node.title?
        %(<listing#{common_attributes node}>
<title>#{node.title}</title>
<p>#{node.content}</p>
</listing>)
      else
        %(<p#{common_attributes node}>#{node.content}</p>)
      end
    end

    alias :preamble :skip

    def quote node
      result = []
      result << %(<quote#{common_attributes node}>)
      result << %(<title>#{node.title}</title>) if node.title?
      result << %(<cite>#{node.attr 'attribution'}</cite>) if node.attr? 'attribution'
      result << (resolve_content node)
      result << %(<p><em>#{node.attr 'citetitle'}</em></p>) if node.attr? 'citetitle'
      result << '</quote>'
      result * EOL
    end

    def thematic_break node
      '<p><?asciidoc-hr?></p>'
    end

    def sidebar node
      %(<note style="sidebar" #{common_attributes node}>
#{title_tag node}#{resolve_content node}
</note>)
    end

    TABLE_PI_NAMES = ['dbhtml', 'dbfo', 'dblatex']
    TABLE_SECTIONS = [:head, :foot, :body]

    def table node
      has_body = false
      result = []
      rules = (node.attr 'grid') ? 'all' : 'none'
      result << %(<table #{common_attributes node} frame="#{node.attr 'frame', 'all'}" rules="#{rules}">)
      result << %(<title>#{node.title}</title>) if node.title?
      if (width = (node.attr? 'width') ? (node.attr 'width') : nil)
        TABLE_PI_NAMES.each do |pi_name|
          result << %(<?#{pi_name} table-width="#{width}"?>)
        end
      end
      result << %(<colgroup>)
      node.columns.each do |col|
        result << %(<col />)
      end
      result << %(</colgroup>)
      TABLE_SECTIONS.select {|tblsec| !node.rows[tblsec].empty? }.each do |tblsec|
        has_body = true if tblsec == :body
        result << %(<t#{tblsec}>)
        node.rows[tblsec].each do |row|
          result << '<tr>'
          row.each do |cell|
            colspan_attribute = cell.colspan ? %( colspan="#{cell.colspan}") : nil
            rowspan_attribute = cell.rowspan ? %( rowspan="#{cell.rowspan}") : nil
            # NOTE <entry> may not have whitespace (e.g., line breaks) as a direct descendant according to DocBook rules
            entry_start = %(<entry#{colspan_attribute}#{rowspan_attribute}>)
            cell_content = if tblsec == :head
              "<p>#{cell.text}</p>"
            else
              case cell.style
              when :asciidoc
                cell.content
              when :verse
                %(<quote>#{cell.text}</quote>)
              when :literal
                %(<listing><code>#{cell.text}</code></listing>)
              when :header
                cell.content.map {|text| %(<p><em style="strong">#{text}</em></p>) }.join
              else
                cell.content.map {|text| %(<p>#{text}</p>) }.join
              end
            end
            entry_end = (node.document.attr? 'cellbgcolor') ? %(<?dbfo bgcolor="#{node.document.attr 'cellbgcolor'}"?></entry>) : '</entry>'
            result << %(#{entry_start}#{cell_content}#{entry_end})
          end
          result << '</tr>'
        end
        result << %(</t#{tblsec}>)
      end
      result << %(</table>)

      warn 'asciidoctor: WARNING: tables must have at least one body row' unless has_body
      result * EOL
    end

    alias :toc :skip

    def ulist node
      result = []
      result << %(<list#{common_attributes node}>)
      result << %(<title>#{node.title}</title>) if node.title?
      node.items.each do |item|
        text_marker = if checklist && (item.attr? 'checkbox')
          (item.attr? 'checked') ? '&#10003; ' : '&#10063; '
        else
          nil
        end
        result << '<item>'
        result << %(<p>#{text_marker}#{item.text}</p>)
        result << item.content if item.blocks?
        result << '</item>'
      end
      result << '</list>'

      result * EOL
    end

    alias :verse :quote

    alias :video :skip
    alias :inline_anchor :skip

    def inline_button node
      %(<gui style="button">#{node.text}</gui>)
    end

    alias :inline_callout :skip

    def inline_break node
      %(#{node.text}<?asciidoc-br?>)
    end

    def inline_footnote node
      if node.type == :xref
        %([&#x2192; <em style="strong">#{node.target}</em> <em>#{node.text}</em>])
      else
        %([<em>#{node.text}</em>])
      end
    end

    def inline_image node
      image node, false
    end

    def inline_indexterm node
      node.type == :visible ? node.text : ''
    end

    def inline_kbd node
      if (keys = node.attr 'keys').size == 1
        %(<key>#{keys[0]}</key>)
      else
        key_combo = keys.map {|key| %(<keycap>#{key}</keycap>) }.join
        %(<keyseq>#{key_combo}</keyseq>)
      end
    end

    def inline_menu node
      menu = node.attr 'menu'
      if !(submenus = node.attr 'submenus').empty?
        submenu_path = submenus.map {|submenu| %(<gui style="menu">#{submenu}</gui> ) }.join.chop
        %(<guiseq><gui style="menu">#{menu}</gui> #{submenu_path} <gui style="menuitem">#{node.attr 'menuitem'}</gui></guiseq>)
      elsif (menuitem = node.attr 'menuitem')
        %(<guiseq><gui style="menu">#{menu}</gui> <gui style="menuitem">#{menuitem}</gui></guiseq>)
      else
        %(<gui style="menu">#{menu}</gui>)
      end
    end

    QUOTE_TAGS = {
      :emphasis    => ['<em>',                '</em>'],
      :strong      => ['<em style="strong">', '</em>'],
      :monospaced  => ['<code>',              '</code>'],
      :double      => ['&#8220;',             '&#8221;'],
      :single      => ['&#8216;',             '&#8217;'],
      :mark        => ['<em style="marked">', '</em>']
    }
    QUOTE_TAGS.default = [nil, nil]

    def inline_quoted node
      if (type = node.type) == :latexmath
        %(<![CDATA[#{node.text}]]>)
      else
        open, close = QUOTE_TAGS[type]
        text = node.text
        if (role = node.role)
          quoted_text = %(#{open}<phrase style="#{role}">#{text}</phrase>#{close})
        else
          quoted_text = %(#{open}#{text}#{close})
        end

        node.id ? %(<span#{common_attributes node}/>#{quoted_text}) : quoted_text
      end
    end

    def author_element doc, index = nil
      firstname_key = index ? %(firstname_#{index}) : 'firstname'
      middlename_key = index ? %(middlename_#{index}) : 'middlename'
      lastname_key = index ? %(lastname_#{index}) : 'lastname'
      email_key = index ? %(email_#{index}) : 'email'

      name = []
      name << doc.attr(firstname_key) if doc.attr? firstname_key
      name << doc.attr(middlename_key) if doc.attr? middlename_key
      name << doc.attr(lastname_key) if doc.attr? lastname_key

      result = []
      result << %(<credit type="author">)
      result << %(<name>#{name.join(' ')}</name>)
      result << %(<email>#{doc.attr email_key}</email>) if doc.attr? email_key
      result << %(</credit>)

      result * EOL
    end

    def common_attributes node, id_attr = false
      # Mallard doesn't natively use xml:id (although it allows
      # foreign-namespaced attributes), but it also has a limited number of
      # places that the id attribute can be used.  Provide xml:id so that XML
      # processing tools can make use of it.
      (id = node.id) ? (id_attr ? %( id="#{id}") : %( xml:id="#{id}")) : ''
    end

    def doctype_declaration root_tag_name
      nil
    end

    def document_info_element doc
      result = []
      result << %(<info>)
      result << %(<date>#{(doc.attr? 'revdate') ? (doc.attr 'revdate') : (doc.attr 'docdate')}</date>)
      if doc.has_header?
        if doc.attr? 'author'
          if (authorcount = (doc.attr 'authorcount').to_i) < 2
            result << (author_element doc)
          else
            authorcount.times do |index|
              result << (author_element doc, index + 1)
            end
          end
        end
        if (doc.attr? 'revdate') || (doc.attr? 'revnumber')
          s = ''
          s << %(<revision )
          s << %(version="#{doc.attr 'revnumber'}" ) if doc.attr? 'revnumber'
          s << %(date="#{doc.attr 'revdate'}" ) if doc.attr? 'revdate'
          s << %(/>)
          result << s
        end
        unless (header_docinfo = doc.docinfo :header).empty?
          result << header_docinfo
        end
        result << %(<orgname>#{doc.attr 'orgname'}</orgname>) if doc.attr? 'orgname'
      end
      result << %(</info>)
      result << document_title_tags(doc.doctitle :partition => true, :use_fallback => true) unless doc.notitle

      result * EOL
    end

    def document_ns_attributes doc
      ' xmlns="http://projectmallard.org/1.0/" xmlns:its="http://www.w3.org/2005/11/its"'
    end

    def lang_attribute_name
      'xml:lang'
    end

    def document_title_tags title
      if title.subtitle?
        %(<title>#{title.main}</title>
<subtitle>#{title.subtitle}</subtitle>)
      else
        %(<title>#{title}</title>)
      end
    end

    # FIXME this should be handled through a template mechanism
    def resolve_content node
      node.content_model == :compound ? node.content : %(<p>#{node.content}</p>)
    end

    def title_tag node, optional = true
      !optional || node.title? ? %(<title>#{node.title}</title>\n) : nil
    end
  end
end
