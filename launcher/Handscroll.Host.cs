// Compiled in memory by Windows PowerShell using the Windows .NET Framework.
using System;
using System.IO;
using System.Net;
using System.Net.Sockets;
using System.Text;
using System.Threading;
using System.Diagnostics;
using System.Collections.Generic;
using System.Security.Cryptography;
using System.Web.Script.Serialization;

namespace Cun {
 public sealed class ScrollHost {
  readonly string root,token,log; readonly object gate=new object(),logGate=new object();
  readonly Dictionary<string,string> receipts=new Dictionary<string,string>(); readonly Queue<string> history=new Queue<string>();
  readonly Semaphore workers=new Semaphore(6,6); string current; Process child; string[] games; byte[] page; string authority;
  long seen=DateTime.UtcNow.Ticks;
  static string Nonce(int count){byte[] b=new byte[count];using(var rng=RandomNumberGenerator.Create())rng.GetBytes(b);return BitConverter.ToString(b).Replace("-","").ToLowerInvariant();}
  bool Files(params string[] names){foreach(var n in names)if(!File.Exists(Path.Combine(root,n)))return false;return true;}
  public ScrollHost(string baseDir){root=Path.GetFullPath(baseDir);token=Nonce(32);log=Path.Combine(root,@".local\mirror-launch.log");var g=new List<string>();
   if(Files("card-demo/project.godot","card-demo/scenes/MainCity.tscn"))g.Add("city");
   if(Files("card-demo/project.godot","card-demo/scenes/Fudi.tscn"))g.Add("fudi");
   if(Files("card-demo/project.godot","card-demo/scenes/WaterActivity.tscn","card-demo/scripts/scenes/underwater_catalog.gd","card-demo/scripts/scenes/underwater_exploration.gd","card-demo/scripts/scenes/water_activity.gd")&&File.ReadAllText(Path.Combine(root,"card-demo/scripts/scenes/water_activity.gd")).Contains("preload(\"res://scripts/scenes/underwater_catalog.gd\")"))g.Add("water");
   if(Files("activities/last-ferry/Play.ps1","activities/last-ferry/game/project.godot","activities/last-ferry/game/main.tscn"))g.Add("ferry");
   games=g.ToArray();if(games.Length==0)throw new IOException("No game projects found. Open Launch.cmd from the complete Cun repository.");
   string html=File.ReadAllText(Path.Combine(root,"launcher/handscroll-bamboo/index.html"));string mark="name=\"cun-mirror-token\" content=\"\"";
   if(!html.Contains(mark)||!html.Contains("name=\"cun-mirror-games\" content=\"\""))throw new InvalidDataException("The scroll page is missing its native launcher markers.");
   page=Encoding.UTF8.GetBytes(html.Replace(mark,"name=\"cun-mirror-token\" content=\""+token+"\"").Replace("name=\"cun-mirror-games\" content=\"\"","name=\"cun-mirror-games\" content=\""+String.Join(" ",games)+"\""));
  }
  void Append(string line){lock(logGate)File.AppendAllText(log,line+Environment.NewLine,new UTF8Encoding(false));}
  void Drain(){if(child!=null&&child.HasExited){child.WaitForExit();int code=child.ExitCode;receipts[current]=code==0?"exited":"failed";child.Dispose();child=null;try{Append("Mirror adapter exited: id="+current+"; code="+code);}catch(IOException){}Interlocked.Exchange(ref seen,DateTime.UtcNow.Ticks);}}
  object Receipt(string id){return id==null?(object)new {state="idle"}:new {state=receipts[id],id=id};}
  object Start(string game,out int code){lock(gate){Drain();if(child!=null){code=409;return new {error="已有作品正在运行。",state="rejected"};}if(Array.IndexOf(games,game)<0){code=404;return new {error="当前仓库缺少对应作品。",state="rejected"};}
   var id=Nonce(12);var p=new Process();p.StartInfo=new ProcessStartInfo(Path.Combine(Environment.SystemDirectory,@"WindowsPowerShell\v1.0\powershell.exe"),"-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File \""+Path.Combine(root,"launcher/Mirror.Game.ps1")+"\" -Game "+game){WorkingDirectory=root,UseShellExecute=false,CreateNoWindow=true,RedirectStandardOutput=true,RedirectStandardError=true};
   DataReceivedEventHandler report=delegate(object s,DataReceivedEventArgs e){if(e.Data!=null){try{Append(e.Data);}catch(IOException){}catch(UnauthorizedAccessException){}}};p.OutputDataReceived+=report;p.ErrorDataReceived+=report;
   try{Directory.CreateDirectory(Path.GetDirectoryName(log));Append("\n["+DateTimeOffset.Now.ToString("o")+"] Mirror / "+game);if(!p.Start())throw new IOException("Process not started");}catch(Exception){p.Dispose();code=500;return new {error="未能启动适配器。请使用经典启动器检查本机配置。",state="rejected"};}
   child=p;current=id;receipts[id]="starting_or_running";history.Enqueue(id);if(history.Count>32)receipts.Remove(history.Dequeue());p.BeginOutputReadLine();p.BeginErrorReadLine();code=202;return Receipt(id);
  }}
  static string Get(Dictionary<string,string> h,string key){string value;return h.TryGetValue(key,out value)?value:"";}
  const string policy="default-src 'none'; script-src 'unsafe-inline'; style-src 'unsafe-inline'; img-src 'self' data:; connect-src 'self'; frame-ancestors 'none'; base-uri 'none'; form-action 'none'";
  static void Reply(Stream s,int code,byte[] body,string type){var h=Encoding.ASCII.GetBytes("HTTP/1.1 "+code+" "+((HttpStatusCode)code).ToString()+"\r\nContent-Type: "+type+"\r\nContent-Length: "+body.Length+"\r\nConnection: close\r\nCache-Control: no-store\r\nReferrer-Policy: no-referrer\r\nX-Content-Type-Options: nosniff\r\nContent-Security-Policy: "+policy+"\r\n\r\n");s.Write(h,0,h.Length);s.Write(body,0,body.Length);}
  static void Json(Stream s,int code,object obj){Reply(s,code,Encoding.UTF8.GetBytes(new JavaScriptSerializer().Serialize(obj)),"application/json; charset=utf-8");}
  void Handle(TcpClient client){using(client){client.ReceiveTimeout=4000;client.SendTimeout=5000;using(var s=client.GetStream()){var h=new Dictionary<string,string>(StringComparer.OrdinalIgnoreCase);var b=new List<byte>();int c;var limit=Stopwatch.StartNew();while(b.Count<12288&&limit.ElapsedMilliseconds<4500&&(c=s.ReadByte())>=0){b.Add((byte)c);int n=b.Count;if(n>=4&&c==10&&b[n-2]==13&&b[n-3]==10&&b[n-4]==13)break;}string raw=Encoding.ASCII.GetString(b.ToArray());if(!raw.EndsWith("\r\n\r\n")){Json(s,400,new{});return;}string[] lines=raw.Split(new[]{"\r\n"},StringSplitOptions.None),req=lines[0].Split(' ');if(req.Length!=3){Json(s,400,new{});return;}for(int i=1;i<lines.Length&&lines[i].Length>0;i++){int k=lines[i].IndexOf(':');if(k<1||h.ContainsKey(lines[i].Substring(0,k))){Json(s,400,new{});return;}h.Add(lines[i].Substring(0,k),lines[i].Substring(k+1).Trim());}
   if(Get(h,"Host")!=authority||h.ContainsKey("Transfer-Encoding")){Json(s,403,new{});return;}
   if(req[0]=="GET"&&req[1]=="/"){Interlocked.Exchange(ref seen,DateTime.UtcNow.Ticks);Reply(s,200,page,"text/html; charset=utf-8");return;}
   if(Get(h,"X-Cun-Token")!=token){Json(s,403,new{});return;}Interlocked.Exchange(ref seen,DateTime.UtcNow.Ticks);
   if(req[0]=="GET"&&(req[1]=="/status"||req[1].StartsWith("/status?id=",StringComparison.Ordinal))){lock(gate){Drain();var id=req[1]=="/status"?current:req[1].Substring(11);if(id!=null&&!receipts.ContainsKey(id))Json(s,404,new{error="游戏回执不存在。"});else Json(s,200,Receipt(id));}return;}
   if(req[0]!="POST"||req[1]!="/launch"){Json(s,404,new{});return;}if(Get(h,"Origin")!="http://"+authority){Json(s,403,new{});return;}int len;if(!Int32.TryParse(Get(h,"Content-Length"),out len)||len<1||len>128||Get(h,"Content-Type").Split(';')[0].Trim()!="application/json"){Json(s,400,new{});return;}byte[] data=new byte[len];for(int n=0,r;n<len;n+=r){if((r=s.Read(data,n,len-n))<=0)return;}
   Dictionary<string,object> msg;try{msg=new JavaScriptSerializer().Deserialize<Dictionary<string,object>>(Encoding.UTF8.GetString(data));}catch(ArgumentException){msg=null;}catch(InvalidOperationException){msg=null;}if(msg==null||msg.Count!=1||!msg.ContainsKey("game")||!(msg["game"] is string)){Json(s,400,new{});return;}int result;object receipt=Start((string)msg["game"],out result);Json(s,result,receipt);
  }}}
  public void Run(){var server=new TcpListener(IPAddress.Loopback,0);server.Start(12);try{authority="127.0.0.1:"+((IPEndPoint)server.LocalEndpoint).Port;string url="http://"+authority+"/";Console.WriteLine("Cun handscroll lobby: "+url);Console.Out.Flush();if(Environment.GetEnvironmentVariable("CUN_HANDSCROLL_NO_BROWSER")!="1"){try{string browser=Environment.GetEnvironmentVariable("CUN_HANDSCROLL_BROWSER");if(String.IsNullOrEmpty(browser)){Process.Start(new ProcessStartInfo(url){UseShellExecute=true});}else{if(!Path.IsPathRooted(browser)||!String.Equals(Path.GetExtension(browser),".exe",StringComparison.OrdinalIgnoreCase)||!File.Exists(browser))throw new IOException("Invalid browser executable");Process.Start(new ProcessStartInfo(browser,url){UseShellExecute=false});}}catch(Exception){Console.WriteLine("Open the address above in your browser.");}}
   while(true){if(!server.Pending()){lock(gate){Drain();if(child==null&&DateTime.UtcNow.Ticks-Interlocked.Read(ref seen)>TimeSpan.FromHours(6).Ticks)break;}Thread.Sleep(50);continue;}TcpClient c=server.AcceptTcpClient();if(!workers.WaitOne(0)){c.Close();continue;}ThreadPool.QueueUserWorkItem(delegate{try{Handle(c);}catch(IOException){}catch(SocketException){}catch(Exception){try{c.Close();}catch{}}finally{workers.Release();}});}
  }finally{server.Stop();}}
 }
}
