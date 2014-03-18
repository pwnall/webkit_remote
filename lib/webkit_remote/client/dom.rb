module WebkitRemote

class Client

# API for the DOM domain.
module Dom
  # @return [WebkitRemote::Client::DomNode] the root DOM node
  def dom_root
    @dom_root ||= dom_root!
  end

  # Obtains the root DOM node, bypassing the cache.
  #
  # @return [WebkitRemote::Client::DomNode] the root DOM node
  def dom_root!
    result = @rpc.call 'DOM.getDocument'
    @dom_root = dom_update_node result['root']
  end

  # Removes all the cached DOM information.
  #
  # @return [WebkitRemote::Client] self
  def clear_dom
    @dom_root = nil
    @dom_nodes.clear
    self
  end

  # Looks up cached information about a DOM node.
  #
  # @private Use WebkitRemote::Client::Dom#query_selector or the other public
  #     APIs instead of calling this directly
  #
  # @param [String] remote_id value of the nodeId attribute in the JSON
  #     returned by a Webkit remote debugging server
  # @return [WebkitRemote::Client::DomNode] cached information about the given
  #     DOM node
  def dom_node(remote_id)
    @dom_nodes[remote_id] ||= WebkitRemote::Client::DomNode.new remote_id, self
  end

  # @private Called by the Client constructor to set up Dom data.
  def initialize_dom
    @dom_nodes = {}
  end

  # Updates cached information about a DOM node.
  #
  # @param [Hash<String, Object>] raw_node a Node data structure in the DOM
  #     domain, as returned by a raw JSON RPC call to a Webkit remote debugging
  #     server
  # @return [WebkitRemote::Client::DomNode] the updated cached information
  def dom_update_node(raw_node)
    remote_id = raw_node['nodeId']
    dom_node(remote_id).update_all raw_node
  end
end  # module WebkitRemote::Client::Dom

initializer :initialize_dom
clearer :clear_dom
include WebkitRemote::Client::Dom

# Cached information about a DOM node.
class DomNode
  # @return [Array<WebkitRemote::Client::DomNode>] children nodes
  attr_reader :children

  # @return [String] the node's local name
  attr_reader :local_name
  # @return [String] the node's name
  attr_reader :name
  # @return [String] the node's value
  attr_reader :value
  # @return [Symbol] the DOM node type (such as :element, :text, :attribute)
  attr_reader :node_type

  # @return [String] name, for attribute nodes
  attr_reader :attr_name
  # @return [String] value, for attribute nodes
  attr_reader :attr_value

  # @return [String] internal subset, for doctype nodes
  attr_reader :internal_subset
  # @return [String] public ID, for doctype nodes
  attr_reader :public_id
  # @return [String] system ID, for doctype nodes
  attr_reader :system_id

  # @return [WebkitRemote::Client::DomNode] content document, for frameowner
  #     nodes
  # @return [String] the document URL, for document and frameowner nodes
  attr_reader :document_url
  # @return [String] the XML version, for document nodes
  attr_reader :xml_version

  # @return [Hash<String, Object>] the node's attributes
  def attributes
    @attributes ||= attributes!
  end

  # Retrieves this node's attributes, bypassing its cache.
  #
  # @return [Hash<String, Object>] the node's attributes
  def attributes!
    result = @client.rpc.call 'DOM.getAttributes', nodeId: @remote_id
    @attributes = Hash[result['attributes'].each_slice(2).to_a]
  end

  # @return [WebkitRemote::Client::JsObject] this node's JavaScript object
  def js_object
    @js_object ||= js_object!
  end

  # Retrieves this node's JavaScript object, bypassing the node's cache.
  #
  # @param [String] group the name of an object group (think memory pools); the
  #     objects in a group can be released together by one call to
  #     WebkitRemote::Client::JsObjectGroup#release
  # @return [WebkitRemote::Client::JsObject] this node's JavaScript object
  def js_object!(group = nil)
    group ||= @client.object_group_auto_name
    result = @client.rpc.call 'DOM.resolveNode', nodeId: @remote_id,
                              groupName: group
    WebkitRemote::Client::JsObject.for result['object'], @client, group
  end

  # @return [String] HTML markup for the node and all its contents
  def outer_html
    @outer_html ||= outer_html!
  end

  # @return [String] HTML markup for the node and all its contents
  def outer_html!
    result = @client.rpc.call 'DOM.getOuterHTML', nodeId: @remote_id
    @outer_html = result['outerHTML']
  end

  # Retrieves the first descendant of this node that matches a CSS selector.
  #
  # @param [String] css_selector the CSS selector that must be matched by the
  #     returned node
  # @return [WebkitRemote::Client::DomNode] the first DOM node in this node's
  #     subtree that matches the given selector; if no such node exists, nil is
  #     returned
  def query_selector(css_selector)
    result = @client.rpc.call 'DOM.querySelector', nodeId: @remote_id,
                              selector: css_selector
    node_id = result['nodeId']
    return nil if node_id == 0
    @client.dom_node result['nodeId']
  end

  # Retrieves all this node's descendants that match a CSS selector.
  #
  # @param [String] css_selector the CSS selector used to filter this node's
  #     subtree
  # @return [Array<WebkitRemote::Client::DomNode>] DOM nodes in this node's
  #     subtree that match the given selector
  def query_selector_all(css_selector)
    result = @client.rpc.call 'DOM.querySelectorAll', nodeId: @remote_id,
                              selector: css_selector
    result['nodeIds'].map { |remote_id| @client.dom_node remote_id }
  end

  # Deletes one of the node (element)'s attributes.
  #
  # @param [String] attr_name name of the attribute that will be deleted
  # @return [WebkitRemote::Client::DomNode] self
  def remove_attribute(attr_name)
    @attributes.delete attr_name if @attributes
    @client.rpc.call 'DOM.removeAttribute', nodeId: @remote_id, name: attr_name
    self
  end

  # Removes this node from the document.
  #
  # @return [WebkitRemote::Client::DomNode] self
  def remove
    @client.rpc.call 'DOM.removeNode', nodeId: @remote_id
    self
  end

  # Highlights this DOM node.
  #
  # @param [Hash<Symbol, Hash>] options colors to be used for highlighting
  # @option options [Hash<Symbol, Number>] margin color used for highlighting
  #     the element's border
  # @option options [Hash<Symbol, Number>] border color used for highlighting
  #     the element's border
  # @option options [Hash<Symbol, Number>] padding color used for highlighting
  #     the element's padding
  # @option options [Hash<Symbol, Number>] content color used for highlighting
  #     the element's content
  # @option options [Boolean] tooltip if true, a tooltip containing node
  #     information is also shown
  def highlight!(options)
    config = {}
    config[:marginColor] = options[:margin] if options[:margin]
    config[:borderColor] = options[:border] if options[:border]
    config[:paddingColor] = options[:padding] if options[:padding]
    config[:contentColor] = options[:content] if options[:content]
    config[:showInfo] = true if options[:tooltip]
    @client.rpc.call 'DOM.highlightNode', nodeId: @remote_id,
                     highlightConfig: config
  end

  # @private Use WebkitRemote::Client::Dom#dom_node instead of calling this
  def initialize(remote_id, client)
    @remote_id = remote_id
    @client = client

    @attributes = nil
    @attr_name = nil
    @attr_value = nil
    @children = nil
    @content_document = nil
    @document_url = nil
    @internal_subset = nil
    @js_object = nil
    @local_name = nil
    @name = nil
    @node_type = nil
    @outer_html = nil
    @public_id = nil
    @system_id = nil
    @value = nil
    @xml_version = nil

    initialize_modules
  end

  def initialize_modules
  end
  private :initialize_modules

  # Registers a module initializer.
  def self.initializer(name)
    before_name = :"initialize_modules_before_#{name}"
    alias_method before_name, :initialize_modules
    private before_name
    remove_method :initialize_modules
    eval <<END_METHOD
      def initialize_modules
        #{name}
        #{before_name.to_s}
      end
END_METHOD
    private :initialize_modules
  end

  # Updates node state to reflect new data from the Webkit debugging server.
  #
  # @private Use WebkitRemote::Client::Dom#dom_node instead of calling this
  #
  # @param [Hash<String, Object>] raw_node a Node data structure in the DOM
  #     domain, as returned by a raw JSON RPC call to a Webkit remote debugging
  #     server
  # @return [WebkitRemote::Client::DomNode] self
  def update_all(raw_node)
    if raw_node['attributes']
      @attributes = Hash[raw_node['attributes'].each_slice(2).to_a]
    end
    if raw_node['children']
      @children = raw_node['children'].map do |child_node|
        @client.dom_update_node child_node
      end
    end
    if raw_node['contentDocument']
      @content_document = @client.dom_update_node raw_node['contentDocument']
    end
    @document_url = raw_node['documentURL'] if raw_node['documentURL']
    @internal_subset = raw_node['internalSubset'] if raw_node['internalSubset']
    @node_local_name = raw_node['localName'] if raw_node['localName']
    @attr_name = raw_node['name'] if raw_node['name']
    @name = raw_node['nodeName'] if raw_node['nodeName']
    if raw_node['nodeType']
      @node_type = NODE_TYPES[raw_node['nodeType'].to_i] || raw_node['nodeType']
    end
    @value = raw_node['nodeValue'] if raw_node['nodeValue']
    @public_id = raw_node['publicId'] if raw_node['publicId']
    @system_id = raw_node['systemId'] if raw_node['systemId']
    @attr_value = raw_node['value'] if raw_node['value']
    @xml_version = raw_node['xmlVersion'] if raw_node['xmlVersion']

    self
  end

  # Maps numeric DOM types to their symbolic representation.
  NODE_TYPES = {
    1 => :element, 2 => :attribute, 3 => :text, 4 => :cdata_section,
    5 => :entity_reference, 6 => :entity, 7 => :processing_instruction,
    8 => :comment, 9 => :document, 10 => :document_type,
    11 => :document_fragment, 12 => :notation
  }.freeze
end   # class WebkitRemote::Client::DomNode

end  # namespace WebkitRemote::Client

end  # namespace WebkitRemote

