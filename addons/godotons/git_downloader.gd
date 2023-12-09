@tool
extends Node
class_name GitDownloader

enum UPSTREAMS { GITHUB = 0, GITLAB }

# quick acess 
const supported: Array[String] = [
    "github",
    "gitlab"
]

static func upstream_name(idx: int) -> String:
    if idx < supported.size():
        return supported[idx]
    return supported[0]

static func upstream_index(name: String) -> UPSTREAMS:
    if name in supported:
        return supported.find(name)
    return -1

class GitSource extends Node:
    var index: UPSTREAMS
    var source_name: String
    var base_url: String
    var api_url: String

    func _init(idx: UPSTREAMS, upstream_name: String, upstream_base_url: String, upstream_api_url: String) -> void:
        index = idx
        source_name = upstream_name
        base_url = upstream_base_url
        api_url = upstream_api_url
    
    func api_hash_url(addon: AddonConfig) -> String:
        match index:
            UPSTREAMS.GITHUB:
                return "https://%s/repos/%s/%s/commits/%s" % [api_url, addon.Owner(), addon.RepoName(), addon.Branch]
            _:
                return ""

    func download_url(addon: AddonConfig) -> String:
        match index:
            UPSTREAMS.GITHUB:
                return "https://%s/%s/%s/archive/%s.zip" % [base_url, addon.Owner(), addon.RepoName(), addon.Branch]
            _:
                return ""

var supported_upstreams: Array[GitSource] = [
    GitSource.new(UPSTREAMS.GITHUB, "github", "github.com", "api.github.com")
]

func index(addon: String) -> UPSTREAMS:
    match addon:
        "github":
            return UPSTREAMS.GITHUB
        "gitlab":
            return UPSTREAMS.GITLAB
        _:
            return UPSTREAMS.GITHUB

func get_source(index: UPSTREAMS) -> GitSource:
    if index > supported_upstreams.size():
        return null
    return supported_upstreams[index]


# get hash of repo:branch
# check if hash.zip exists in tmp_dir 
# if not download it 
func get_commit_hash(addon: AddonConfig, token: String = "") -> String:
    var req: HTTPRequest = HTTPRequest.new()
    add_child(req)

    var url: String = get_source(index(addon.Origin)).api_hash_url(addon)

    var headers: PackedStringArray = []
    if token != "":
        var header_auth: String = "Authorization: token %s" % [token]
        headers.append(header_auth)
    var header_accept: String = "Accept: application/vnd.github.VERSION.sha"
    headers.append(header_accept)

    var request_error: Error = req.request(url, headers)
    if request_error != OK:
        Logs._error("Failed to fetch commit hash from %s" % [url], request_error)
        return ""

    var resp: Array = await req.request_completed

    var result: int = resp[0]
    var response_code: int = resp[1]
    var h: PackedStringArray = resp[2]
    var body: PackedByteArray = resp[3]

    if response_code != 200:
        Logs._error("Response code (%d) while retrieving git hash from upstream (%s). Expected 200 and others unhandled." % [response_code, url], result)
        return ""

    return body.get_string_from_utf8()

func get_archive(addon: AddonConfig, filepath: String, token: String = "") -> Error:
    var req: HTTPRequest = HTTPRequest.new()
    add_child(req)

    var url: String = get_source(index(addon.Origin)).download_url(addon)

    var headers: PackedStringArray = []
    if token != "":
        var header_auth: String = "Authorization: token %s" % [token]
        headers.append(header_auth)

    var request_err: Error = req.request(url, headers)
    if request_err != OK:
        Logs._error("Failed to download %s" % [url], request_err)
        return request_err
    
    Logs._infoi("Awaiting %s..." % [url])

    var response: Array = await req.request_completed

    var result: int = response[0]
    var response_code: int = response[1]
    var resp_headers: PackedStringArray = response[2]
    var body: PackedByteArray = response[3]

    if response_code != 200:
        Logs._error("Response code (%d) while retrieving %s. Expected 200 and others unhandled." % [response_code, url], result)
        return result

    Logs._successi("Fetched %s. Writing to %s..." % [url, filepath])

    var file: FileAccess = FileAccess.open(filepath, FileAccess.WRITE)

    if !file:
        Logs._error("Failed to create file %s" % [filepath], file.get_open_error())
        return file.get_open_error()
    
    file.store_buffer(body)
    file.close()

    return OK