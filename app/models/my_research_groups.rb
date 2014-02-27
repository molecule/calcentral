class MyResearchGroups < UserSpecificModel
  include ClassLogger
  extend Calcentral::Cacheable

  def initialize(uid)
    @uid = uid
  end

  def get_feed_internal
    response = {
        :research => []
    }
    response[:research].concat(process_research_sites) if Settings.features.research && ResearchUserProxy.access_granted?(@uid)
    logger.debug "#{self.class.name} get_feed is #{response.inspect}"
    response
  end

  private

  def process_research_sites
    research_proxy = ResearchUserProxy.new({:user_id => @uid})
    research_proxy.get_feed[:research] || []
  end
end
