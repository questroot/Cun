using System;
using System.Collections.Generic;
using System.IO;
using System.Text.RegularExpressions;

namespace Cun {
    internal sealed class ScrollEntry {
        public string Id, Title, Project, Scene;
        public bool Warm, Available;
    }

    internal static class ScrollCatalog {
        public static ScrollEntry[] Load(string root) {
            var entries=new List<ScrollEntry>();var ids=new HashSet<string>(StringComparer.Ordinal);
            string warmProject=null;
            foreach(string line in File.ReadAllLines(Path.Combine(root,"launcher/entries.tsv"))) {
                if(String.IsNullOrWhiteSpace(line)||line.StartsWith("#",StringComparison.Ordinal))continue;
                string[] row=line.Split('\t');
                if(row.Length!=5||!Regex.IsMatch(row[0],@"\A[a-z][a-z0-9-]{0,31}\z")||row[0]=="warm"||!ids.Add(row[0])||
                    String.IsNullOrWhiteSpace(row[1])||row[1].Length>32||!Relative(row[2])||!Relative(row[3])||
                    !row[3].EndsWith(".tscn",StringComparison.Ordinal)||(row[4]!="warm"&&row[4]!="ondemand"))
                    throw new InvalidDataException("入口清单含无效或重复条目："+line);
                var entry=new ScrollEntry{Id=row[0],Title=row[1],Project=row[2],Scene=row[3],Warm=row[4]=="warm"};
                if(entry.Warm){if(warmProject!=null&&warmProject!=entry.Project)throw new InvalidDataException("入口清单只允许一个预热工程。");warmProject=entry.Project;}
                string project=Path.Combine(root,entry.Project);
                entry.Available=File.Exists(Path.Combine(project,"project.godot"))&&File.Exists(Path.Combine(project,entry.Scene));
                if(entry.Id=="water") {
                    string surface=Path.Combine(project,"scripts/scenes/water_activity.gd");
                    entry.Available=entry.Available&&File.Exists(Path.Combine(project,"scripts/scenes/underwater_catalog.gd"))&&
                        File.Exists(Path.Combine(project,"scripts/scenes/underwater_exploration.gd"))&&File.Exists(surface)&&
                        File.ReadAllText(surface).Contains("preload(\"res://scripts/scenes/underwater_catalog.gd\")");
                }
                entries.Add(entry);
            }
            if(entries.Count==0)throw new InvalidDataException("入口清单没有游戏。");
            return entries.ToArray();
        }
        static bool Relative(string path) {
            if(!Regex.IsMatch(path,@"\A[A-Za-z0-9_.-]+(?:/[A-Za-z0-9_.-]+)*\z"))return false;
            foreach(string part in path.Split('/'))if(part=="."||part=="..")return false;
            return true;
        }
    }
}
