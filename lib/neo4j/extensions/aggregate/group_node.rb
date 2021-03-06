module Neo4j::Aggregate

# This is the group node. When a new aggregate group is created it will be of this type.
# Includes the Enumerable mixin in order to iterator over each node member in the group.
# Overrides [] and []= properties, so that we can access aggregated properties or relationships.
#
# :api: private
  class AggregateGroupNode #:nodoc:
    include Neo4j::NodeMixin
    include Enumerable

    property :aggregate_group, :aggregate_size

    def self.create(aggregate_group)
      new_node = AggregateGroupNode.new
      new_node.aggregate_group = aggregate_group.kind_of?(Symbol)? aggregate_group.to_s : aggregate_group
      new_node.aggregate_size = 0
      new_node
    end

    def each
      relationships.outgoing.nodes.each { |n| yield n }
    end

    # :api: private
    def get_property(key)
      value = super(key)
      return value unless value.nil?

      sub_group = relationships.outgoing(key).nodes.first
      return sub_group unless sub_group.nil?

      # traverse all sub nodes and get their properties
      PropertyEnum.new(relationships.outgoing.nodes, key)
    end

    def set_property(key, value)
      super key, value
      val = self.get_property(key)
    end
  end

end
