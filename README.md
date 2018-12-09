<h1 align="center">
  <a name="logo" href="http://www.vCloudInfo.com/search/label/iot"><img src="https://raw.githubusercontent.com/CCOSTAN/Home-AssistantConfig/master/config/www/custom_ui/floorplan/images/branding/twitter_profile.png" alt="Bear Stone Smart Home" width="200"></a>
  <br>
  Bear Stone Smart Home Configuration
</h1>
<h4 align="center">Be sure to :star: my repo so you can keep up to date on the daily progress!.</h4>
<div align="center">
  <h4>
    <a href="https://travis-ci.org/CCOSTAN/Home-AssistantConfig"><img src="https://travis-ci.org/CCOSTAN/Home-AssistantConfig.svg?branch=master"/></a>
    <a href="https://github.com/CCOSTAN/Home-AssistantConfig/stargazers"><img src="https://img.shields.io/github/stars/CCOSTAN/Home-AssistantConfig.svg?style=plasticr"/></a>
    <a href="https://github.com/CCOSTAN/Home-AssistantConfig/commits/master"><img src="https://img.shields.io/github/last-commit/CCOSTAN/Home-AssistantConfig.svg?style=plasticr"/></a>
  </h4>
</div>
<p align="center"><a align="center" target="_blank" href="https://vcloudinfo.us12.list-manage.com/subscribe?u=45cab4343ffdbeb9667c28a26&id=e01847e94f"><img src="http://feeds.feedburner.com/RecentCommitsToBearStoneHA.1.gif" alt="Recent Commits to Bear Stone Smart Home" style="border:0"></a></p>
<div align="center"><a name="menu"></a>
  <h4>
    <a href="http://www.vCloudInfo.com/search/label/iot">
      Blog
    </a>
    <span> | </span>
    <a href="https://github.com/CCOSTAN/Home-AssistantConfig#devices">
      Devices
    </a>
    <span> | </span>
    <a href="https://github.com/CCOSTAN/Home-AssistantConfig/issues">
      Todo List
    </a>
    <span> | </span>
    <a href="https://twitter.com/BearStoneHA">
      Smart Home Stats
    </a>
    <span> | </span>
    <a href="https://www.facebook.com/BearStoneHA">
      Facebook
    </a>
    <span> | </span>
    <a href="https://github.com/CCOSTAN/Home-AssistantConfig/tree/master/config">
      Code
    </a>
    <span> | </span>
    <a href="https://github.com/CCOSTAN/Home-AssistantConfig#diagram">
      Diagram
    </a>    
    <span> | </span>
    <a href="https://youtube.com/CCOSTAN">
      Youtube
    </a>
    <span> | </span>
    <a href="https://www.vcloudinfo.com/p/shop-our-merch.html">
      Tee Shop
    </a>
  </h4>

Over the years, the security zone to which the current page belongs has disappeared from the Internet Explorer status bar, as has the current folder's security zone from the Windows/File Explorer status bar.  With IE, it's a mere inconvenience, as the security zone can still be determined from the page's Properties dialog, but no such information is available for the current folder in Windows Explorer, nor can a folder's security zone be determined using any built-in Windows tool (okay, that I'm aware of – I don't need grief from the PowerShell crowd!)
Why does this matter?  For one thing, by default, Windows still considers any network location containing dots in its server specification (for example an IP address or a fully qualified DNS name, such as a DFS share) as belonging to the Internet security zone, which depending on the applicable security settings in a given situation may either block or issue a warning when any user attempts to open a document or launch an executable or script from such a location.   Note that in many cases the reason for the block or warning may not be obvious even to a knowledgeable user because a drive letter (that happens to have been mapped to, say, a DFS share) is being accessed.  Other reasons to care about an item’s security zone include the possibility that the location may have been miscategorized via some central policy (as for example Trusted rather than Intranet), or in the case of a single file that it may bear a “Mark-of-the-Web” (MOTW), for example the NTFS Alternate Data Stream named Zone.Identifier attached to files downloaded from sites in the Internet or Restricted zones.
This is where the new IPM command line utility GetSecZone comes in:  it reports the security zone associated with any URL or fully specified file system object, both displayed by name and number and as a return code (%ErrorLevel%) for scripting purposes. 

<a name="bottom" href="https://github.com/CCOSTAN/Home-AssistantConfig#logo"><img align="right" border="0" src="https://raw.githubusercontent.com/CCOSTAN/Home-AssistantConfig/master/config/www/custom_ui/floorplan/images/branding/up_arrow.png" width="25" ></a>

**Still have questions on my Config?**
**Message me on twitter :** [@CCostan](https://twitter.com/ccostan) or [@BearStoneHA](https://twitter.com/BearStoneHA)
<!-- Subscribe Section -->
<a href="http://eepurl.com/dmXFYz"><img align="center" border="0" src="https://raw.githubusercontent.com/CCOSTAN/Home-AssistantConfig/master/config/www/custom_ui/floorplan/images/branding/email_link.png" height="50" ></a>.
<!-- Subscribe Section END-->
