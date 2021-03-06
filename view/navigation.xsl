<!-- This stylesheet is concerned with rendering the navigational
     components of the site (menus, breadcrumbs, etc.)
-->
<xsl:stylesheet version="2.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  xmlns:xdmp="http://marklogic.com/xdmp"
  xmlns      ="http://www.w3.org/1999/xhtml"
  xmlns:xhtml="http://www.w3.org/1999/xhtml"
  xmlns:u    ="http://marklogic.com/rundmc/util"
  xmlns:users="users"
  xmlns:ml   ="http://developer.marklogic.com/site/internal"
  xmlns:srv  ="http://marklogic.com/rundmc/server-urls"
  xpath-default-namespace="http://developer.marklogic.com/site/internal"
  exclude-result-prefixes="xs ml xdmp srv">

  <xsl:import href="pre-process-navigation.xsl"/>


  <!-- The page occurs in the hierarchy either explicitly or as encompassed by a wildcard.

       If the exact URI is found, then use that;
       otherwise, look to see if the current page falls under a content-type wildcard.

       If the URI is found more than once (as may happen with blog posts), only the first one is chosen.
  -->
  <xsl:variable name="page-in-navigation" select="($navigation//*    [@pref eq '1'][@href eq $external-uri],
                                                   $navigation//*            [@href eq $external-uri],
                                                   $navigation//Article      [$content/Article/@type eq @type],
                                                   $navigation//Announcement [$content/Announcement],
                                                   $navigation//Event        [$content/Event],
                                                   $navigation//generic-page[@tutorial][starts-with($external-uri,@href)]
                                                  )[1]"/>

  <!-- Home page link always points to primary server (even from API server) -->
  <xsl:template match="xhtml:a/@ml:href[. eq '/']">
    <xsl:attribute name="href">
      <xsl:value-of select="$srv:primary-server"/>
    </xsl:attribute>
  </xsl:template>

  <!-- Don't show the login menu when we're viewing the standalone docs app -->
  <xsl:template match="login-menu[$srv:viewing-standalone-api]"/>

  <xsl:template match="login-menu">
    <nav id="login-menu-nav">
        <xsl:if test="not(users:signupsEnabled())">
            <xsl:attribute name="style">display:none</xsl:attribute>
        </xsl:if>
        <ul>
            <li>
                <a class="drop-down-trigger button" id="signup-trigger" href="{$srv:primary-server}/people/signup"><xsl:if
                    test="users:getCurrentUserName()"> <xsl:attribute name="style">display:none</xsl:attribute> </xsl:if>
                <span>Sign up</span></a>
            </li>
            <li>
                <a class="drop-down-trigger button" id="login-trigger" href="#"><xsl:if 
                    test="users:getCurrentUserName()"> <xsl:attribute name="style">display:none</xsl:attribute> </xsl:if>
                <span>Log in</span></a>
            </li>
            <li>
                <a class="drop-down-trigger button" id="session-trigger" href="#"><xsl:if 
                    test="empty(users:getCurrentUserName())"> <xsl:attribute name="style">display:none</xsl:attribute> </xsl:if>
                <span><xsl:value-of select="users:getCurrentUserName()"></xsl:value-of></span></a>
            </li>
        </ul>
    </nav>
    <fieldset id="login-menu" class="drop-down-menu">
        <form id="local-login-form" style="display: block" method="post" action="{$srv:primary-server}/login">
            <span style="clear: both" id="login-error"/>
            <p>
                <div class="login-menu-label">Email </div>
                <input id="email" name="email" value="" title="email" type="text" autocomplete="on"/>
            </p>
            <p>
                <div class="login-menu-label">Password</div> 
                <input id="password" name="password" value="" title="password" type="password" autocomplete="on"/>
            </p>
            <a class="button" id="login_submit" href="#" type="button"><span>Log in</span></a>
        </form>
        <div style="float: right"><a href="{$srv:primary-server}/people/recovery" id="recovery">Forgot password?</a></div>
    </fieldset>
    <fieldset id="session-menu" class="drop-down-menu">
        <p> <a id="profile" href="{$srv:primary-server}/people/profile"><span>Edit Profile</span></a> </p>
        <p id="separator"/>
        <p class="last">
            <a id="logout" href="#"><span>Log out</span></a>
        </p>
    </fieldset>
  </xsl:template>

  <xsl:template match="top-nav">
    <nav>
      <ul>
        <xsl:apply-templates mode="top-nav" select="$navigation/*/page[not(@hide eq 'yes')]"/>
      </ul>
    </nav>
  </xsl:template>

          <xsl:template mode="top-nav" match="page">
            <li>
              <xsl:apply-templates mode="top-nav-current-att" select="."/>
              <xsl:variable name="server-prefix">
                <xsl:apply-templates mode="top-nav-server-prefix" select="."/>
              </xsl:variable>
              <xsl:variable name="href">
                <xsl:apply-templates mode="top-nav-href" select="."/>
              </xsl:variable>
              <a href="{$server-prefix}{$href}" class="stip" title="{@tooltip}">
                <xsl:apply-templates mode="nav-text" select="@display"/>
              </a>
            </li>
          </xsl:template>

                  <!-- overridden by admin code -->
                  <xsl:template mode="top-nav-server-prefix" match="page" as="xs:string">
                    <xsl:sequence select="if (starts-with(@href,'/')) then if (@api-server)
                                                                           then $srv:api-server
                                                                           else $srv:primary-server
                                                                      else ''"/>
                  </xsl:template>

                  <!-- In the standalone version, top nav links point to the Community site... -->
                  <xsl:template mode="top-nav-server-prefix" match="page[$srv:viewing-standalone-api]">
                    <xsl:sequence select="if (starts-with(@href,'/')) then 'http://developer.marklogic.com' else ''"/>
                 </xsl:template>

                  <!-- ...except for "Documentation," which points to the root of the current server -->
                  <xsl:template mode="top-nav-server-prefix" match="page[$srv:viewing-standalone-api][@href eq '/']" priority="1"/>


                  <xsl:template mode="top-nav-href" match="page">
                    <xsl:value-of select="@href"/>
                    <xsl:apply-templates mode="top-nav-href-suffix" select="."/>
                  </xsl:template>

                          <xsl:template mode="top-nav-href-suffix" match="page"/>
                          <xsl:template mode="top-nav-href-suffix" match="page[@use-preferred-version-href][not($preferred-version eq $ml:default-version)]">
                            <xsl:value-of select="$preferred-version"/>
                          </xsl:template>


                  <xsl:template mode="top-nav-current-att" match="page"/>

                  <xsl:template mode="top-nav-current-att" match="page[descendant-or-self::* intersect $page-in-navigation][not(@api-server)]
                                                                | page[@api-server and $currently-on-api-server]">
                    <xsl:attribute name="class">current</xsl:attribute>
                  </xsl:template>

                          <!-- overridden in apidoc/view/page.xsl -->
                          <xsl:variable name="currently-on-api-server" select="false()"/>


  <xsl:template mode="nav-text" match="@display">
    <xsl:analyze-string select="." regex="&#174;">
      <xsl:matching-substring>
        <sup>
          <xsl:value-of select="."/>
        </sup>
      </xsl:matching-substring>
      <xsl:non-matching-substring>
        <xsl:value-of select="."/>
      </xsl:non-matching-substring>
    </xsl:analyze-string>
  </xsl:template>

  <xsl:template match="doc-breadcrumbs"/>
  <!-- Only display this for Learn docs -->
  <xsl:template match="doc-breadcrumbs[$content/Article]">
    <div id="content_title">
      <xsl:call-template name="breadcrumbs"/>
    </div>
  </xsl:template>

  <!-- For Learn content, breadcrumbs are handled elsewhere -->
  <!-- since when?
  <xsl:template match="breadcrumbs[$content/Article]"/>
  -->

  <xsl:template match="breadcrumbs" name="breadcrumbs">
    <xsl:apply-templates mode="breadcrumbs" select="$page-in-navigation[1]"/>
    <!-- Append the "Server version" switcher if we're on the search results page -->
    <xsl:apply-templates mode="version-list" select=".[$external-uri = ('/search','/apidoc/do-search')]"/>
  </xsl:template>

          <!-- No breadcrumbs on home page -->
          <xsl:template mode="breadcrumbs" match="page[@href eq '/']"/>

          <!-- But do display them on every other page -->
          <xsl:template mode="breadcrumbs" match="*" name="breadcrumbs-impl">
            <xsl:param name="site-name" select="'Developer Community'"/>
            <div>
              <a href="/">
                <xsl:value-of select="$site-name"/>
              </a>
              <xsl:apply-templates mode="breadcrumb-link" select="ancestor::page"/>
              <xsl:apply-templates mode="breadcrumb-display" select="."/>
            </div>
          </xsl:template>

                  <xsl:template mode="breadcrumb-display" match="page | generic-page">
                    <xsl:text> > </xsl:text>
                    <xsl:apply-templates mode="nav-text" select="@display"/>
                  </xsl:template>

                  <xsl:template mode="breadcrumb-display" match="*">
                    <xsl:text> > </xsl:text>
                    <xsl:value-of select="$content/*/title"/>
                  </xsl:template>


                  <xsl:template mode="breadcrumb-link" match="page">
                    <xsl:text> > </xsl:text>
                    <a href="{@href}">
                      <xsl:apply-templates mode="nav-text" select="@display"/>
                    </a>
                  </xsl:template>

  <xsl:template match="sub-nav[$content/Article]">
    <xsl:if test="$content//(xhtml:h3 | xhtml:figure)">
      <h2>Contents</h2>
      <ul class="tutorial_toc">
        <!-- If the article doesn't have any <h3> headings, then display the list of figures instead. -->
        <xsl:apply-templates mode="article-toc" select="if ($content//xhtml:h3)
                                                       then $content//xhtml:h3
                                                       else $content//xhtml:figure"/>
      </ul>
    </xsl:if>
  </xsl:template>

          <xsl:template mode="article-toc" match="xhtml:h3 | xhtml:figure">
            <li>
              <span>
                <xsl:apply-templates mode="article-toc-link" select="."/>
              </span>
            </li>
          </xsl:template>

                  <xsl:template mode="article-toc-link" match="xhtml:h3">
                    <a href="#{generate-id(.)}">
                      <xsl:value-of select="."/>
                    </a>
                  </xsl:template>

                  <xsl:template mode="article-toc-link" match="xhtml:figure">
                    <a href="#{@id}">
                      <xsl:value-of select="."/>
                    </a>
                  </xsl:template>

          <xsl:template match="xhtml:h3" priority="1">
            <xsl:param name="annotate-headings" tunnel="yes" select="false()"/>
            <xsl:choose>
              <xsl:when test="$annotate-headings">
                <h3>
                  <xsl:apply-templates select="@*"/>
                  <a name="{generate-id(.)}"/>
                  <xsl:apply-templates/>
                </h3>
              </xsl:when>
              <xsl:otherwise>
                <xsl:next-match/>
              </xsl:otherwise>
            </xsl:choose>
          </xsl:template>


  <xsl:template match="sub-nav">
    <xsl:variable name="sub-nav-root" select="$page-in-navigation/ancestor-or-self::page[group | page]"/>
    <xsl:variable name="children" select="$sub-nav-root/(group | page)"/>
    <xsl:if test="$children">
      <div class="subnav {if ($sub-nav-root/@closed eq 'yes') then 'closed' else ''}">
        <xsl:choose>
          <xsl:when test="$children/self::group">
            <xsl:apply-templates mode="sub-nav" select="$children"/>
          </xsl:when>
          <!-- Otherwise, they're not grouped; they're just pages in one list -->
          <xsl:otherwise>
            <ul>
              <xsl:apply-templates mode="sub-nav" select="$children"/>
            </ul>
          </xsl:otherwise>
        </xsl:choose>
      </div>
    </xsl:if>
  </xsl:template>

          <xsl:template mode="sub-nav" match="group">
            <h2>
              <xsl:apply-templates mode="nav-text" select="@display"/>
            </h2>
            <ul>
              <xsl:apply-templates mode="sub-nav" select="page | group"/>
            </ul>
          </xsl:template>

                  <xsl:template mode="sub-nav" match="group/group">
                    <li>
                      <xsl:apply-templates mode="sub-nav-current-att" select="."/>
                      <span>
                        <xsl:apply-templates mode="nav-text" select="@display"/>
                      </span>
                      <ul>
                        <xsl:apply-templates mode="sub-nav" select="page | group"/>
                      </ul>
                    </li>
                  </xsl:template>


                  <!-- TODO: Find out whether nested lists should be supported. The JavaScript appears to be broken currently. -->
                  <xsl:template mode="sub-nav" match="page[ not(exists(./@hide)) ] ">
                    <li>
                        <xsl:apply-templates mode="sub-nav-current-att" select="."/>
                            <a href="{@href}">
                               <xsl:variable name="short-description"
                                             select="document(concat(@href, '.xml'))//ml:short-description"/>
                               <xsl:if test="$short-description">
                                    <xsl:attribute name="class">stip</xsl:attribute>
                                    <xsl:attribute name="title">
                                        <xsl:value-of select="$short-description"/>
                                    </xsl:attribute>
                                </xsl:if>
                                <xsl:apply-templates mode="nav-text" select="@display"/>
                            </a>
                    </li>
                  </xsl:template>

                          <xsl:template mode="sub-nav-current-att" match="*"/>

                          <xsl:template mode="sub-nav-current-att" match="*[. intersect $page-in-navigation/ancestor-or-self::*]
                                                                        | *[@href eq ancestor::page/@href
                                                                                 and ancestor::page intersect $page-in-navigation]">
                            <xsl:attribute name="class">current</xsl:attribute>
                          </xsl:template>

                          <!-- Exception: don't expand when initial expansion is explicitly disabled. This is useful
                               for the "Blog" navigation in particular, where a post may appear in multiple places in the sub-navigation.
                          -->
                          <xsl:template mode="sub-nav-current-att" match="group[@disable-initial-expansion eq 'yes']//page" priority="1"/>


          <xsl:template mode="sub-nav" match="blog-posts-grouped-by-date">
            <xsl:variable name="tree">
            </xsl:variable>
          </xsl:template>


  <!-- We use an id on certain pages (search results) -->
  <xsl:template match="xhtml:body/@ml:id[$external-uri = ('/search','/apidoc/do-search')]" priority="1">
    <xsl:attribute name="id" select="'results'"/>
  </xsl:template>
  <!-- but not others -->
  <xsl:template match="xhtml:body/@ml:id"/>


  <!-- The <body> CSS class varies from page to page -->
  <xsl:template match="xhtml:body/@ml:class">
    <xsl:attribute name="class">
      <xsl:apply-templates mode="body-class"        select="$page-in-navigation[1]"/>
      <xsl:apply-templates mode="body-class-extra"  select="$content"/>
    </xsl:attribute>
  </xsl:template>

          <!-- "blog" is a misnomer, but it means: collapse the sub-nav by default -->
          <xsl:template mode="body-class" match="page[@closed eq 'yes']
                                               | *   [@closed eq 'yes']//page">blog</xsl:template>
          <xsl:template mode="body-class" match="*"/>

          <xsl:template mode="body-class-extra" match="*[@disable-comments eq 'yes']"> nocomments</xsl:template>
          <xsl:template mode="body-class-extra" match="*"/>

  <xsl:template match="page-nav">
        <div class="pagination_nav">
            <xsl:if test="$content/page/@page/number() gt 1">
            <p class="pagination_prev"><a 
                href="{doc($content/page/@nav)/nav/page[position() = ($content/page/@page/number() - 1)]/@href/string()}" 
                class="btn btn_blue">&#171; Previous</a><span>
                <xsl:value-of select="doc($content/page/@nav)/nav/page[position() = ($content/page/@page/number() - 1)]/string()"/></span></p>
            </xsl:if>
            <xsl:if test="$content/page/@page/number() lt count(doc($content/page/@nav)/nav/page/number())">
            <p class="pagination_next"><a 
                href="{doc($content/page/@nav)/nav/page[position() = ($content/page/@page/number() + 1)]/@href/string()}" 
                class="btn btn_blue">Next &#187;</a><span> 
                <xsl:value-of select="doc($content/page/@nav)/nav/page[position() = ($content/page/@page/number() + 1)]/string()"/></span></p>
            </xsl:if>
        </div>
  </xsl:template>

  <xsl:template match="sub-nav[$content/page/@multi]">
      <section class="subnav">
      <h2>Contents</h2>
      <ul class="categories multi-page-toc">
          <xsl:apply-templates mode="multi-page-toc" select="doc($content/page/@nav)/nav/page"/>
      </ul>
      </section>
  </xsl:template>

          <xsl:template mode="multi-page-toc" match="page">
            <li>
              <xsl:if test="position() = $content/ml:page/@page/number()">
                 <xsl:attribute name="class">current</xsl:attribute>
              </xsl:if>
              <a href="{@href}" class="stip">
                 <xsl:value-of select="string()"/>
              </a>
            </li>
          </xsl:template>


  <xsl:template match="sub-nav[$content/Tutorial or $content/page/tutorial]">
    <section class="subnav">
      <h2>Contents</h2>
      <ul class="tutorial_toc">
        <xsl:apply-templates mode="tutorial-toc" select="ml:parent-tutorial($original-content/*)/Body/(pages|pages/page)"/>
      </ul>
    </section>
  </xsl:template>

          <xsl:template mode="tutorial-toc" match="pages | page">
            <xsl:variable name="is-current-page" select="self::pages[$original-content/Tutorial]
                                                      or @url-name eq ml:tutorial-page-url-name($original-content)"/>
            <li>
              <xsl:if test="$is-current-page">
                 <xsl:attribute name="class" select="'current'"/>
              </xsl:if>
              <xsl:variable name="href">
                <xsl:apply-templates mode="tutorial-page-href" select="."/>
              </xsl:variable>
              <span>
                <a href="{$href}" class="stip">
                  <xsl:apply-templates mode="tutorial-page-title" select="."/>
                </a>
              </span>
              <xsl:if test="$is-current-page">
                <ul>
                  <xsl:apply-templates mode="tutorial-toc-section" select="$content//xhtml:h3"/>
                </ul>
              </xsl:if>
            </li>
          </xsl:template>

                  <xsl:template mode="tutorial-toc-section" match="xhtml:h3">
                    <li>
                      <a href="#{@id}">
                        <xsl:value-of select="."/>
                      </a>
                    </li>
                  </xsl:template>

</xsl:stylesheet>
