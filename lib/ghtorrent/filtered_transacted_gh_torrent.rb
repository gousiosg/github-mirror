require 'ghtorrent/transacted_gh_torrent'

class FilteredTransactedGHTorrent < TransactedGHTorrent
  attr_reader :org_filter

  def initialize(settings)
    @org_filter = load_orgs_file(config(:mirror_orgs_file))
    super
  end 

  def ensure_repo(owner, repo, recursive = false)
    if org_filter.include?(owner)
      super
    else
      warn "Organization #{owner} excluded by filter"
      return
    end
  end

  def ensure_org(organization, members = true)
    if org_filter.include?(organization)
      super
    else
      warn "Organization #{organization} excluded by filter"
      return
    end
  end

  def ensure_repo_recursive(owner, repo)
    if org_filter.include?(owner)
      super
    else
      warn "Organization #{owner} excluded by filter"
      return
    end
  end

  private

  def load_orgs_file(path)
    result = Set.new
    return result unless File.exists?(path)
     
    IO.foreach(path) do |x|
      x = x.strip
      if x.empty? == false
        result.add(x)
      end
    end
    result
  end
end
