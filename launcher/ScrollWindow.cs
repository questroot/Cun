using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Text;
using System.Globalization;
using System.Runtime.InteropServices;
using System.Windows.Interop;
using System.Windows;
using System.Windows.Automation;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Threading;

namespace Cun {
    public sealed class ScrollWindow : Window {
        readonly string root, log;
        readonly object logLock = new object();
        readonly ScrollArtwork art;
        readonly Canvas labels = new Canvas();
        readonly Button[] places = new Button[4];
        readonly string[] ids = {"city", "fudi", "water", "ferry"};
        readonly string[] names = {"灵伴回合冒险", "福地", "海底水世界", "末班渡船"};
        readonly string[] numerals = {"壹", "贰", "叁", "肆"};
        readonly TextBlock title, press, edition, credit, notice;
        readonly Button action;
        readonly Stopwatch clock = Stopwatch.StartNew();
        readonly DispatcherTimer timer = new DispatcherTimer(DispatcherPriority.Render);
        readonly bool animate = SystemParameters.ClientAreaAnimation;
        enum Phase { Opening, Hall, Entering, Playing, Failed }
        Phase phase = Phase.Opening; double phaseStart, lastAmbient = -100; int chosen; bool laidOut;
        Process game;
        IntPtr hostHandle, gameHandle;
        uint enginePid;
        bool closeRequested;
        double launchTime, closeTime, nextFitCheck, fitCheckUntil;
        static readonly FontFamily Serif = new FontFamily("Georgia, KaiTi, SimSun");
        const int WindowStyleIndex = -16, ExStyle = -20, WmClose = 0x10;
        const uint Child = 0x40000000, Popup = 0x80000000;
        [StructLayout(LayoutKind.Sequential)] struct RECT { public int L,T,R,B; }
        delegate bool WindowVisitor(IntPtr hwnd, IntPtr unused);
        [DllImport("user32.dll")] static extern bool EnumWindows(WindowVisitor visit, IntPtr unused);
        [DllImport("user32.dll")] static extern IntPtr GetWindow(IntPtr hwnd, uint code);
        [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr hwnd, out uint pid);
        [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern int GetClassName(IntPtr hwnd, StringBuilder name, int length);
        [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr hwnd);
        [DllImport("user32.dll")] static extern uint GetWindowLong(IntPtr hwnd,int index);
        [DllImport("user32.dll")] static extern uint SetWindowLong(IntPtr hwnd,int index,uint value);
        [DllImport("user32.dll", SetLastError=true)] static extern IntPtr SetParent(IntPtr hwnd, IntPtr parent);
        [DllImport("user32.dll")] static extern IntPtr GetParent(IntPtr hwnd);
        [DllImport("user32.dll")] static extern bool GetClientRect(IntPtr hwnd, out RECT rect);
        [DllImport("user32.dll")] static extern bool SetWindowPos(IntPtr hwnd,IntPtr after,int x,int y,int w,int h,uint flags);
        [DllImport("user32.dll")] static extern bool ShowWindow(IntPtr hwnd,int command);
        [DllImport("user32.dll")] static extern bool PostMessage(IntPtr hwnd,int msg,IntPtr wp,IntPtr lp);
        [DllImport("user32.dll")] static extern IntPtr GetForegroundWindow();
        [DllImport("user32.dll")] static extern bool AttachThreadInput(uint a,uint b,bool attach);
        [DllImport("user32.dll")] static extern IntPtr SetFocus(IntPtr hwnd);
        static readonly Brush Gold = BrushFrom("#C8B38C"), Ivory = BrushFrom("#F1E4CA");
        static SolidColorBrush BrushFrom(string hex){var b=(SolidColorBrush)new BrushConverter().ConvertFromString(hex);b.Freeze();return b;}
        static TextBlock Text(string s,double z,Brush brush){return new TextBlock {Text=s,FontSize=z,FontFamily=Serif,Foreground=brush,IsHitTestVisible=false};}
        static Button Flat(string label,string id){var b=new Button{Content=label,FontFamily=Serif,FontSize=15,Foreground=Ivory,Background=Brushes.Transparent,BorderThickness=new Thickness(0),Cursor=Cursors.Hand,Padding=new Thickness(2)};
            var template=new ControlTemplate(typeof(Button));var border=new FrameworkElementFactory(typeof(Border));border.SetValue(Border.BackgroundProperty,Brushes.Transparent);var presenter=new FrameworkElementFactory(typeof(ContentPresenter));presenter.SetValue(FrameworkElement.HorizontalAlignmentProperty,HorizontalAlignment.Center);presenter.SetValue(FrameworkElement.VerticalAlignmentProperty,VerticalAlignment.Bottom);border.AppendChild(presenter);template.VisualTree=border;b.Template=template;
            AutomationProperties.SetAutomationId(b,id);AutomationProperties.SetName(b,label);return b;}
        bool Exists(params string[] paths){foreach(string p in paths)if(!File.Exists(Path.Combine(root,p)))return false;return true;}
        bool Available(int i){if(i==3)return Exists("activities/last-ferry/game/project.godot","activities/last-ferry/game/main.tscn","activities/last-ferry/Play.ps1");if(!Exists("card-demo/project.godot"))return false;if(i!=2)return Exists(i==0?"card-demo/scenes/MainCity.tscn":"card-demo/scenes/Fudi.tscn");return Exists("card-demo/scenes/WaterActivity.tscn","card-demo/scripts/scenes/underwater_catalog.gd","card-demo/scripts/scenes/underwater_exploration.gd","card-demo/scripts/scenes/water_activity.gd")&&File.ReadAllText(Path.Combine(root,"card-demo/scripts/scenes/water_activity.gd")).Contains("preload(\"res://scripts/scenes/underwater_catalog.gd\")");}
        public ScrollWindow(string rootDir){root=rootDir;log=Path.Combine(root,".local/mirror-launch.log");Title="山海行卷 · Cun";WindowStartupLocation=WindowStartupLocation.CenterScreen;Width=Math.Min(1280,SystemParameters.WorkArea.Width);Height=Math.Min(780,SystemParameters.WorkArea.Height);MinWidth=Math.Min(620,SystemParameters.WorkArea.Width);MinHeight=Math.Min(440,SystemParameters.WorkArea.Height);Background=BrushFrom("#192827");UseLayoutRounding=true;
            art=new ScrollArtwork(Path.Combine(root,"launcher/handscroll-bamboo/landscape.png"));var g=new Grid();g.ClipToBounds=true;g.Children.Add(art);g.Children.Add(labels);Content=g;
            press=Text("CUN    /    异 境 图 志",12,Gold);title=Text("山 海 行 卷",38,Ivory);edition=Text("Landscapes of Passage   ·   I",17,Gold);edition.FontStyle=FontStyles.Italic;credit=Text("手卷第一　／　设色山水",12,Gold);notice=Text("",17,Ivory);notice.TextWrapping=TextWrapping.Wrap;
            foreach(var t in new[]{press,title,edition,credit,notice})labels.Children.Add(t);
            for(int i=0;i<4;i++){int index=i;var b=Flat(names[i],ids[i]);var caption=new TextBlock{FontFamily=Serif,FontSize=20,Foreground=Ivory};caption.Inlines.Add(new System.Windows.Documents.Run(numerals[i]+"  "){FontSize=12,Foreground=Gold});caption.Inlines.Add(names[i]);b.Content=caption;b.IsEnabled=Available(i);if(!b.IsEnabled){b.Opacity=.42;b.ToolTip="此副本未包含完整作品";}b.Click+=delegate{Enter(index);};b.MouseEnter+=delegate{caption.TextDecorations=TextDecorations.Underline;};b.MouseLeave+=delegate{caption.TextDecorations=b.IsKeyboardFocused?TextDecorations.Underline:null;};b.GotKeyboardFocus+=delegate{caption.TextDecorations=TextDecorations.Underline;};b.LostKeyboardFocus+=delegate{if(!b.IsMouseOver)caption.TextDecorations=null;};places[i]=b;labels.Children.Add(b);}
            action=Flat("跳过展卷  Esc","scrollAction");labels.Children.Add(action);action.Click+=delegate{if(phase==Phase.Opening||phase==Phase.Entering||phase==Phase.Failed)Hall(true);else if(phase==Phase.Hall)Open();};
            PreviewKeyDown+=delegate(object s,KeyEventArgs e){if(e.Key==Key.Escape&&(phase==Phase.Opening||phase==Phase.Entering||phase==Phase.Failed)){Hall(true);e.Handled=true;}else if(phase==Phase.Hall&&(e.Key==Key.Left||e.Key==Key.Right)){int i=Array.FindIndex(places,z=>z.IsKeyboardFocused);for(int k=1;k<=4;k++){int next=(i+(e.Key==Key.Left?-k:k)+8)%4;if(places[next].IsEnabled){places[next].Focus();break;}}e.Handled=true;}};
            labels.SizeChanged+=delegate{Relayout();FitGame();};
            SourceInitialized+=delegate{hostHandle=new WindowInteropHelper(this).Handle;};
            Loaded+=delegate{Relayout();Open();timer.Start();};Closed+=delegate{timer.Stop();};
            Closing+=delegate(object s,System.ComponentModel.CancelEventArgs e){if(game!=null){e.Cancel=true;RequestGameClose();}};
            timer.Interval=TimeSpan.FromMilliseconds(33);timer.Tick+=delegate{Tick();};}
        static double Smooth(double t){t=Math.Max(0,Math.Min(1,t));return t*t*t*(10+t*(-15+t*6));}
        static void Pos(UIElement e,double x,double y){Canvas.SetLeft(e,x);Canvas.SetTop(e,y);}
        void Relayout(){double w=labels.ActualWidth,h=labels.ActualHeight;if(w<1||h<1)return;laidOut=true;var r=art.ArtBounds;double pad=Math.Max(22,w*.052),bottom=h-Math.Max(31,h*.065),gap=Math.Max(24,Math.Min(42,h*.047));
            Pos(press,pad,Math.Max(12,r.Top*.23));title.FontSize=Math.Max(24,Math.Min(44,r.Top*.27));Pos(title,pad,Math.Max(31,r.Top*.38));edition.Visibility=w<750?Visibility.Hidden:Visibility.Visible;Pos(edition,w-pad-208,Math.Max(26,r.Top*.40));Pos(credit,pad,bottom);Pos(action,w-pad-124,bottom-9);action.Width=124;action.Height=32;
            for(int i=0;i<4;i++){var b=places[i];b.Width=r.Width/4;b.Height=r.Height+gap+22;Pos(b,r.Left+i*r.Width/4,r.Top);((TextBlock)b.Content).FontSize=Math.Max(14,Math.Min(w*.016,23));}Pos(notice,pad,h*.79);notice.Width=w-2*pad;}
        void SetUI(bool hall,bool overview,string button){foreach(var b in places)b.Visibility=hall?Visibility.Visible:Visibility.Collapsed;foreach(var t in new[]{press,title,credit,edition})t.Opacity=overview?1:0;action.Content=button;action.Visibility=button==null?Visibility.Hidden:Visibility.Visible;AutomationProperties.SetName(action,button??"");}
        void Open(){phaseStart=clock.Elapsed.TotalSeconds;phase=Phase.Opening;notice.Text="";art.Zoom=0;art.Open=0;SetUI(false,true,"跳过展卷  Esc");if(!animate)Hall(false);else art.InvalidateVisual();}
        void Hall(bool focus){phase=Phase.Hall;notice.Text="";art.Open=1;art.Zoom=0;SetUI(true,true,"重展手卷 ↶");if(focus&&places[chosen].IsEnabled)places[chosen].Focus();art.InvalidateVisual();}
        void Enter(int i){if(phase!=Phase.Hall||!places[i].IsEnabled)return;phase=Phase.Entering;phaseStart=clock.Elapsed.TotalSeconds;chosen=i;art.Selection=i;SetUI(false,false,null);StartGame();}
        void Tick(){if(!laidOut)return;double now=clock.Elapsed.TotalSeconds,dt=now-phaseStart;
            if(phase==Phase.Entering){
                art.TimeSeconds=animate?now:0;art.Zoom=animate?Smooth(dt/.92):1;art.InvalidateVisual();
                if(!animate||dt>=.92||closeRequested){phase=Phase.Playing;if(!closeRequested)notice.Text="正在进入「"+names[chosen]+"」…";PollGame(now);}return;
            }
            if(phase==Phase.Playing){PollGame(now);return;}if(WindowState==WindowState.Minimized)return;if(phase==Phase.Hall||phase==Phase.Failed){if(!animate||!IsActive||now-lastAmbient<.066)return;lastAmbient=now;}art.TimeSeconds=animate?now:0;
            if(phase==Phase.Opening){art.Open=Smooth((dt-.16)/2.56);if(dt>=3)Hall(false);}art.InvalidateVisual();}
        void Append(string s){lock(logLock){File.AppendAllText(log,s+Environment.NewLine,new UTF8Encoding(false));}}
        void Fail(string message){phase=Phase.Failed;SetUI(false,false,"返回全卷 ↶");notice.Text=message;action.Focus();}
        void Log(string s){try{Append(s);}catch(IOException){}catch(UnauthorizedAccessException){}}
        // --wid identifies the owned Godot window from its first frame. Godot
        // 4.7 on Windows uses WS_POPUP, so make it a real child before showing it.
        void FitGame(){RECT r;uint pid;
            if(gameHandle==IntPtr.Zero||GetWindowThreadProcessId(gameHandle,out pid)==0||pid!=enginePid)return;
            if(GetClientRect(hostHandle,out r)&&r.R>0&&r.B>0)
                SetWindowPos(gameHandle,IntPtr.Zero,0,0,r.R,r.B,0x4214); // no z-order/activation, async
        }
        void FocusGame(){if(GetForegroundWindow()!=hostHandle)return;
            uint ignored, from=GetWindowThreadProcessId(hostHandle,out ignored),to=GetWindowThreadProcessId(gameHandle,out ignored);
            if(to==0||!AttachThreadInput(from,to,true))return;
            try{SetFocus(gameHandle);}finally{AttachThreadInput(from,to,false);}}
        void MountGame(){IntPtr found=IntPtr.Zero;
            EnumWindows(delegate(IntPtr h,IntPtr unused){uint pid;
                if(GetWindowThreadProcessId(h,out pid)==0||pid!=enginePid||!IsWindowVisible(h)||GetWindow(h,4)!=hostHandle)return true;
                var name=new StringBuilder(48);GetClassName(h,name,name.Capacity);if(name.ToString()!="Engine")return true;
                found=h;return false;
            },IntPtr.Zero);
            if(found==IntPtr.Zero)return;
            uint original=GetWindowLong(found,WindowStyleIndex), ex=GetWindowLong(found,ExStyle);
            ShowWindow(found,0);
            SetWindowLong(found,WindowStyleIndex,(original&~(Popup|0x00CF0000u))|Child|0x04000000u);
            SetWindowLong(found,ExStyle,ex&~(0x00040000u|0x00000100u));
            SetParent(found,hostHandle);
            if(GetParent(found)!=hostHandle||(GetWindowLong(found,WindowStyleIndex)&Child)==0){
                SetWindowLong(found,WindowStyleIndex,original);SetWindowLong(found,ExStyle,ex);
                Log("Desktop mount failed: game="+ids[chosen]);PostMessage(found,WmClose,IntPtr.Zero,IntPtr.Zero);return;
            }
            gameHandle=found;notice.Text="";FitGame();
            nextFitCheck=clock.Elapsed.TotalSeconds+.20;fitCheckUntil=nextFitCheck+1;
            Log("Desktop mounted: game="+ids[chosen]+"; hwnd="+found.ToInt64()+"; click_ms="+Math.Round((clock.Elapsed.TotalSeconds-launchTime)*1000).ToString(CultureInfo.InvariantCulture));
            ShowWindow(found,4);FocusGame();
            if(closeRequested){closeRequested=false;RequestGameClose();}
        }
        void RequestGameClose(){
            uint pid;if(gameHandle!=IntPtr.Zero&&GetWindowThreadProcessId(gameHandle,out pid)!=0&&pid==enginePid){
                // The game may show a save prompt or decline close. Do not latch
                // this request once it has been delivered: × must work again.
                PostMessage(gameHandle,WmClose,IntPtr.Zero,IntPtr.Zero);return;
            }
            if(closeRequested)return;closeRequested=true;closeTime=clock.Elapsed.TotalSeconds;notice.Text="正在退出…";
        }
        void PollGame(double now){
            if(game==null||game.HasExited)return;
            if(enginePid!=0&&gameHandle==IntPtr.Zero)MountGame();
            // The engine can still apply its initial bounds after it becomes visible.
            // Reconcile client size briefly across the first frames, then use resize events.
            if(gameHandle!=IntPtr.Zero&&nextFitCheck>0&&now>=nextFitCheck){
                FitGame();nextFitCheck=now<fitCheckUntil?now+.25:0;
            }
            // A normal exit is requested through Godot's window-close event. If
            // the user closes during import, the request is delivered on mount.
            if(closeRequested&&now-closeTime>4&&gameHandle==IntPtr.Zero)
                notice.Text="正在等待资源准备结束后退出…";
            else if(!closeRequested&&now-launchTime>20&&gameHandle==IntPtr.Zero)
                notice.Text="仍在准备「"+names[chosen]+"」…";
        }
        void StartGame(){if(phase!=Phase.Entering)return;notice.Text="";
            enginePid=0;gameHandle=IntPtr.Zero;closeRequested=false;launchTime=clock.Elapsed.TotalSeconds;
            var p=new Process();string adapter=Path.Combine(root,"launcher/Mirror.Game.ps1"), id=ids[chosen];
            p.StartInfo=new ProcessStartInfo(Path.Combine(Environment.SystemDirectory,@"WindowsPowerShell\v1.0\powershell.exe"),"-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File \""+adapter+"\" -Game "+id+" -ParentWindow "+hostHandle.ToInt64().ToString(CultureInfo.InvariantCulture)){WorkingDirectory=root,UseShellExecute=false,CreateNoWindow=true,RedirectStandardOutput=true,RedirectStandardError=true};
            DataReceivedEventHandler receive=delegate(object sender,DataReceivedEventArgs e){if(e.Data!=null)Log(e.Data);};
            p.OutputDataReceived+=receive;p.ErrorDataReceived+=receive;
            p.OutputDataReceived+=delegate(object sender,DataReceivedEventArgs e){
                string prefix="Mirror engine launcher started: game="+id+"; launch_pid=";uint pid;
                if(e.Data!=null&&e.Data.StartsWith(prefix,StringComparison.Ordinal)&&uint.TryParse(e.Data.Substring(prefix.Length),out pid))
                    Dispatcher.BeginInvoke(new Action(delegate{if(game==p)enginePid=pid;}));
            };
            p.EnableRaisingEvents=true;p.Exited+=delegate{Dispatcher.BeginInvoke(new Action(delegate{
                if(game!=p)return;p.WaitForExit();int code=p.ExitCode;bool mounted=gameHandle!=IntPtr.Zero;game=null;gameHandle=IntPtr.Zero;enginePid=0;p.Dispose();
                Log("Desktop adapter exited: game="+id+"; code="+code);
                if(closeRequested||code==0){Close();return;}
                if(WindowState==WindowState.Minimized)WindowState=WindowState.Normal;
                Activate();if(code==42)Hall(true);
                else if(mounted) Close();
                else Fail("未能正常运行「"+names[chosen]+"」。请查看 .local/mirror-launch.log，或使用经典启动器检查引擎。");
            }));};
            try{Directory.CreateDirectory(Path.GetDirectoryName(log));Append("\n["+DateTimeOffset.Now.ToString("o")+"] Mirror / "+id);game=p;if(!p.Start())throw new IOException("Process did not start");}catch(Exception ex){game=null;p.Dispose();Fail("无法启动「"+names[chosen]+"」："+ex.Message);return;}p.BeginOutputReadLine();p.BeginErrorReadLine();}
        [STAThread] public static int Main(string[] args){try{string dir=Path.GetDirectoryName(typeof(ScrollWindow).Assembly.Location);while(dir!=null&&!File.Exists(Path.Combine(dir,"launcher/Mirror.Game.ps1")))dir=Path.GetDirectoryName(dir);if(dir==null)throw new DirectoryNotFoundException("请从完整游戏目录启动。");var app=new Application();app.Run(new ScrollWindow(dir));return 0;}catch(Exception e){MessageBox.Show(e.GetBaseException().Message,"山海行卷",MessageBoxButton.OK,MessageBoxImage.Error);return 1;}}
    }
}
