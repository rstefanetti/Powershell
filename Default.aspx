<%@ Import Namespace="System" %>
<%@ Import Namespace="System.IO" %>
<%@ Import Namespace="System.Web" %>
<%@ Import Namespace="System.Xml" %>
<%@ Import Namespace="System.Reflection" %>
<%@ Page Language="c#" debug="true" %>
<script runat="server">

private XmlDocument customSettings = null;

private void include(string Filename)
{
  Filename = Server.MapPath(".") + @"\" + Filename;
  if (File.Exists(Filename)) {
    Response.Write(File.ReadAllText(Filename));
  }
}

private string getHost()
{
  GetCustomSettings();
  var uri = new Uri(customSettings.SelectSingleNode("//appSettings/add[@key='PublicWebBaseUrl']").Attributes["value"].Value);
  return uri.Host;
}

private void GetCustomSettings()
{
  if (this.customSettings == null)
  {
    customSettings = new XmlDocument();
    customSettings.Load(@"C:\Program Files\Microsoft Dynamics NAV\80\Service\CustomSettings.config");
  }
}

private string getSharePointUrl()
{
  var ascxFilename = @"c:\inetpub\wwwroot\NAV\WebClient\desktop.ascx";
  var ascx = File.ReadAllText(ascxFilename);
  var idx = ascx.IndexOf("')\"><img Src=\"/AAD/WebClient/Resources/Images/Office.png\"");
  if (idx > 0) {
    var tagIdx = ascx.Substring(0, idx).LastIndexOf("<a href=\"javascript:O365('");
    var url = ascx.Substring(tagIdx + 26, idx - tagIdx - 26);
    return url;
  }
  return "";
}

private string getServerInstance()
{
  GetCustomSettings();
  return customSettings.SelectSingleNode("//appSettings/add[@key='ServerInstance']").Attributes["value"].Value;
}

private bool isMultitenant()
{
  GetCustomSettings();
  return bool.Parse(customSettings.SelectSingleNode("//appSettings/add[@key='Multitenant']").Attributes["value"].Value.ToLowerInvariant());
}

private string[] getTenants()
{
  return File.ReadAllLines(Server.MapPath(".") + @"\tenants.txt");
}

</script>

<html>
<head>
    <title>Microsoft Dynamics NAV 2015 Demonstration Environment</title>
    <style type="text/css">
        h1 {
            font-size: 3em;
            font-weight: 100;
            color: #000;
            margin: 0px;
        }

        h2 {
            font-size: 1.2em;
            margin-top: 2em;
        }

        .h2sub {
            font-weight: 100;
        }

        h3 {
            font-size: 1.4em;
            margin: 0px;
            line-height: 32pt;
        }

        h4 {
            font-size: 1em;
            margin: 0px;
            line-height: 24pt;
        }

        h6 {
            font-size: 10pt;
            position: relative;
            left: 10px;
            top: 120px;
            margin: 0px;
        }

        h5 {
            font-size: 10pt;
        }

        body {
            font-family: "Segoe UI","Lucida Grande",Verdana,Arial,Helvetica,sans-serif;
            font-size: 12px;
            color: #5f5f5f;
            margin-left: 20px;
        }

        table {
            table-layout: fixed;
            width: 100%;
        }

        td {
            vertical-align: top;
        }

        a {
            text-decoration: none;
            text-underline:none
        }
        #tenants {
            border-collapse:collapse;
        }

        #tenants td {
            text-align: center;
            border: 1px solid #808080;
            vertical-align: middle;
            margin: 2px 2px 2px 2px;
        }

	#tenants tr.alt td {
            background-color: #e0e0e0;
        }

	#tenants tr.head td {
            background-color: #c0c0c0;
        }

        #tenants td.tenant {
            text-align: left;
        }
    </style>
</head>
<body>
  <table>
    <colgroup>
       <col span="1" style="width: 14%;">
       <col span="1" style="width: 70%;">
       <col span="1" style="width:  1%;">
       <col span="1" style="width: 15%;">
    </colgroup>
    <tr><td colspan="4"><h1>Microsoft Dynamics NAV 2015 Demonstration Environment</h1></td></tr>
<%
  if (File.Exists(Server.MapPath(".") + @"\Certificate.cer")) {
%>
    <tr><td colspan="4"><h3>Download Self Signed Certificate</h3></td></tr>
    <tr>
      <td colspan="2">The Demonstration Environment is secured with a self-signed certificate. In order to connect to the environment, you must trust this certificate. The process for downloading and trusting the certificate depends on the operating system and browser:</td>
      <td></td>
      <td rowspan="5"><a href="http://<% =getHost() %>/Certificate.cer">Download certificate</a></td>
    </tr>
    <tr>
      <td>Windows (IE/Chrome)</td>
      <td>Download and open the certificate file. Click <i>Install Certificate</i>, choose <i>Local Machine</i>, and then place the certificate in the <i>Trusted Root Certification Authorities</i> category.</td>
      <td></td>
    </tr>
    <tr>
      <td>Windows (Firefox)</td>
      <td>Open Options, Advanced, View Certificates, Servers and then choose <i>Add Exception</i>. Enter <i>https://<% =getHost() %>/NAV</i>, choose <i>Get Certificate</i>, and then choose <i>Confirm Security Exception</i>.</td>
      <td></td>
    </tr>
    <tr>
      <td>iPad (Safari)</td>
      <td>Choose the <i>download certificate</i> link. Install the certificate by following the certificate installation process.</td>
      <td></td>
    </tr>
    <tr>
      <td>Android</td>
      <td>Choose the <i>download certificate</i> link. Launch the downloaded certificate, and then choose OK to install the certificate.</td>
      <td></td>
    </tr>
<%
  }
  var rdps = System.IO.Directory.GetFiles(Server.MapPath("."), "*.rdp");
  if (rdps.Length > 0) {
%>
    <tr><td colspan="4"><h3>Remote Desktop Access</h3></td></tr>
<%
    for(int i=0; i<rdps.Length; i++) {
%>
      <tr>
        <td colspan="2">
<%
      if (i == 0) {
        if (rdps.Length > 1) {
%>
The demo environment contains multiple servers. You can connect to the individual servers by following these links.
<%
        } else {
%>
You can connect to the server in the demo environment by following this link.
<%
        }
      }
%>
        </td>
        <td></td>
        <td><a href="http://<% =getHost() %>/<% =System.IO.Path.GetFileName(rdps[i]) %>"><% =System.IO.Path.GetFileNameWithoutExtension(rdps[i]) %></a></td>
      </tr>
<%
    }
  }
  if (!isMultitenant())
  {
  if (Directory.Exists(@"c:\inetpub\wwwroot\NAV")) {
%>
    <tr><td colspan="4"><h3>Access the Demonstration Environment using UserName/Password Authentication</h3></td></tr>
    <tr>
      <td colspan="2">If you have installed the Microsoft Dynamics NAV 2015 tablet app and want to configure the app to connect to this Microsoft Dynamics NAV 2015 Demonstration Environment, choose this link.</td>
      <td></td>  
      <td><a href="ms-dynamicsnav://<% =getHost() %>/NAV" target="_blank">Configure tablet app</a></td>
    </tr>
    <tr>
      <td colspan="2">Choose this link to access the Demonstration Environment using the Microsoft Dynamics NAV 2015 Web client.</td>
      <td></td>  
      <td><a href="https://<% =getHost() %>/NAV" target="_blank">Access Web Client</a></td>
    </tr>
<%
    if (File.Exists(@"c:\inetpub\wwwroot\NAV\WebClient\map.aspx")) {
%>
    <tr>
      <td colspan="2">The Microsoft Dynamics NAV 2015 Demonstration Environment is integrated with Bing Maps. Choose this link to view a map showing all customers.</td>
      <td></td>  
      <td><a href="https://<% =getHost() %>/NAV/WebClient/map.aspx" target="_blank">Show Customer Map</a></td>
    </tr>
<%
    }
    if (Directory.Exists(Server.MapPath(".") + @"\NAV")) {
%>
    <tr>
      <td colspan="2">The Microsoft Dynamics NAV 2015 Demonstration Environment supports running the Microsoft Dynamics NAV Windows client over the internet. Choose this link to install the Microsoft Dynamics NAV Windows client using ClickOnce.</td>
      <td></td>  
      <td><a href="http://<% =getHost() %>/NAV" target="_blank">Install Windows Client</a></td>
    </tr>
<%
    }
  }
  if (Directory.Exists(@"c:\inetpub\wwwroot\AAD")) {
%>
    <tr><td colspan="4"><h3>Access the Demonstration Environment using Microsoft Azure Active Directory or Office 365 authentication</h3></td></tr>
    <tr>
      <td colspan="2">If you have installed the Microsoft Dynamics NAV 2015 tablet app and want to configure the app to connect to this Microsoft Dynamics NAV 2015 Demonstration Environment, choose this link.</td>
      <td></td>  
      <td><a href="ms-dynamicsnav://<% =getHost() %>/AAD" target="_blank">Configure tablet app</a></td>
    </tr>
    <tr>
      <td colspan="2">Choose this link to access the Demonstration Environment using the Microsoft Dynamics NAV 2015 Web client.</td>
      <td></td>  
      <td><a href="https://<% =getHost() %>/AAD" target="_blank">Access Web Client</a></td>
    </tr>
    <tr>
      <td colspan="2">Choose this link to access the Demonstration Environment from Microsoft Dynamics NAV 2015 embedded in an Office 365 SharePoint site.</td>
      <td></td>  
      <td><a href="<% =getSharePointUrl() %>" target="_blank">Access SharePoint Site</a></td>
    </tr>
<%
    if (File.Exists(@"c:\inetpub\wwwroot\AAD\WebClient\map.aspx")) {
%>
    <tr>
      <td colspan="2">The Microsoft Dynamics NAV 2015 Demonstration Environment is integrated with Bing Maps. Choose this link to view a map showing all customers.</td>
      <td></td>  
      <td><a href="https://<% =getHost() %>/AAD/WebClient/map.aspx" target="_blank">Show Customer Map</a></td>
    </tr>
<%
    }
    if (Directory.Exists(Server.MapPath(".") + @"\AAD")) {
%>
    <tr>
      <td colspan="2">The Microsoft Dynamics NAV 2015 Demonstration Environment supports running the Microsoft Dynamics NAV Windows client over the internet. Choose this link to install the Microsoft Dynamics NAV Windows client using ClickOnce.</td>
      <td></td>  
      <td><a href="http://<% =getHost() %>/AAD" target="_blank">Install Windows Client</a></td>
    </tr>
<%
    }
  }
%>
    <tr><td colspan="4"><h3>Access the Demonstration Environment using Web Services</h3></td></tr>
    <tr>
      <td colspan="2">The Microsoft Dynamics NAV 2015 Demonstration Environment exposes functionality as SOAP web services. Choose this link to view the web services.</td>
      <td></td>  
      <td><a href="https://<% =getHost() %>:7047/NAV/WS/Services" target="_blank">View SOAP Web Services</a></td>
    </tr>
    <tr>
      <td colspan="2">The Demonstration Environment exposes data as restful OData web services. Choose this link to view the web services</td>
      <td></td>  
      <td><a href="https://<% =getHost() %>:7048/NAV/OData" target="_blank">View OData Web Services</a></td>
    </tr>
<%
  } 
  else
  {
%>
    <tr><td colspan="4"><h3>Multitenant Demonstration Environment</h3></td></tr>
    <tr>
      <td colspan="4">
      <p>The Microsoft Dynamics NAV 2015 Demonstration Environment is multitenant. The Tenants section lists the tenants, and you can choose links to access each of them.</p>
      <p>If you have installed the Microsoft Dynamics NAV 2015 tablet app and want to configure the app to connect to a tenant in this Demonstration Environment, choose the <i>Configure app</i> link.</p>
      <p>You can access this Demonstration Environment using the Microsoft Dynamics NAV 2015 Web client by choosing the <i>Web Client</i> link.</p>
      <p>You can access the Demonstration Environment from the Microsoft Dynamics NAV Windows client over the internet. You can install the Microsoft Dynamics NAV 2015 Windows client and connect to a specific tenant using ClickOnce by choosing the <i>Windows Client</i> link.</p>
      <p>The Demonstration Environment exposes functionality as SOAP web services and restful OData web services. You can view the services by choosing the relevant link. <b>Note:</b> You must specify the tenant in the username (<i>&lt;tenant&gt;\&lt;username&gt;</i>).
      </td>
    </tr>
    <tr>
      <td colspan="4">
        <table id="tenants">
          <tr class="head">
            <td class="tenant"><b>Tenants</b></td>
            <td colspan="4" align="center"><b>Username/Password Authentication</b></td>
<%
if (Directory.Exists(@"c:\inetpub\wwwroot\AAD")) {
%>
            <td colspan="4" align="center"><b>AAD or O365 Authentication</b></td>
<%
}
%>
            <td colspan="2" align="center"><b>Web Services</b></td>
          </tr>
<%
var alt = false;
foreach(var tenant in getTenants())
{
if (alt) {
%>
          <tr class="alt">
<%
} else {
%>
          <tr>
<%
}
alt = !alt;
%>
            <td class="tenant">
              <b><% =tenant %></b>
            </td>
            <td>
              <a href="ms-dynamicsnav://<% =getHost() %>/NAV?tenant=<% =tenant %>" target="_blank">Configure app</a>
            </td>
            <td>
              <a href="https://<% =getHost() %>/NAV?tenant=<% =tenant %>" target="_blank">Web Client</a>
            </td>
            <td>
<%
if (Directory.Exists(Server.MapPath(".") + @"\" + tenant)) {
%>
              <a href="http://<% =getHost() %>/<% =tenant %>" target="_blank">Windows Client</a>
<%
}
%>
            </td>
            <td>
<%
if (File.Exists(@"c:\inetpub\wwwroot\NAV\WebClient\map.aspx")) {
%>
              <a href="https://<% =getHost() %>/NAV/WebClient/map.aspx?tenant=<% =tenant %>" target="_blank">Customer Map</a>
<%
}
%>
            </td>
<%
if (Directory.Exists(@"c:\inetpub\wwwroot\AAD")) {
%>
            <td>
              <a href="ms-dynamicsnav://<% =getHost() %>/AAD?tenant=<% =tenant %>" target="_blank">Configure app</a>
            </td>
            <td>
              <a href="https://<% =getHost() %>/AAD?tenant=<% =tenant %>" target="_blank">Web Client</a>
            </td>
            <td>
              <a href="<% =getSharePointUrl() %>/sites/<% =tenant %>" target="_blank">SharePoint Site</a>
            </td>
            <td>
<%
if (File.Exists(@"c:\inetpub\wwwroot\AAD\WebClient\map.aspx")) {
%>
              <a href="https://<% =getHost() %>/AAD/WebClient/map.aspx?tenant=<% =tenant %>" target="_blank">Customer Map</a>
<%
}
%>
            </td>
<%
}
%>
            <td>
              <a href="https://<% =getHost() %>:7047/NAV/WS/Services?tenant=<% =tenant %>" target="_blank">Soap Web Services</a>
            </td>
            <td>
              <a href="https://<% =getHost() %>:7048/NAV/OData?tenant=<% =tenant %>" target="_blank">OData Web Services</a>
            </td>
          </tr>
<%
}
%>
        </table>
      </td>
    </tr>
<%
  }
%>
    <tr><td colspan="4"><h3>Access the Demonstration Environment Help Server</h3></td></tr>
    <tr>
      <td colspan="2">Choose this link to access the Microsoft Dynamics NAV 2015 Help Server.</td>
      <td></td>  
      <td><a href="http://<% =getHost() %>:49000/main.aspx?lang=en&content=conGettingStarted.htm" target="_blank">View Help Content</a></td>
    </tr>
    <tr><td colspan="4">&nbsp;</td></tr>

  </table>
</body>
</html>