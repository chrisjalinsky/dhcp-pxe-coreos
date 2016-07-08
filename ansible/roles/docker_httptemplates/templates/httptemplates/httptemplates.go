{% raw %}package main

import (
	"io/ioutil"
	"html/template"
	"net/http"
	"regexp"
	"errors"
	"os"
	"sort"
	"strconv"
	"time"
	"flag"
)

var tmpldir = flag.String("tmpldir", "templates", "The templates directory")
var httpport = flag.String("httpport", "8085", "The port to serve http on")
var datadir = flag.String("datadir", "data", "The data directory")
var templates = template.Must(template.ParseFiles(*tmpldir+"/edit.html", *tmpldir+"/view.html", *tmpldir+"/index.html"))
var validPath = regexp.MustCompile("^/(edit|save|view)/([a-zA-Z0-9]+)$")

func getTitle(w http.ResponseWriter, r *http.Request) (string, error) {
  m := validPath.FindStringSubmatch(r.URL.Path)
  if m == nil {
    http.NotFound(w, r)
    return "", errors.New("Invalid Page Title")
  }
  return m[2], nil
}

func renderTemplate(w http.ResponseWriter, tmpl string, p *Page) {
	err := templates.ExecuteTemplate(w, tmpl, p)
	if err != nil {
  	http.Error(w, err.Error(), http.StatusInternalServerError)
	}
}

func renderIndexTemplate(w http.ResponseWriter, tmpl string, b []FileInfo) {
	err := templates.ExecuteTemplate(w, tmpl, b)
	if err != nil {
  	http.Error(w, err.Error(), http.StatusInternalServerError)
	}
}

func makeHandler(fn func (http.ResponseWriter, *http.Request, string)) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		m := validPath.FindStringSubmatch(r.URL.Path)
    if m == nil {
      http.NotFound(w, r)
      return
    }
    fn(w, r, m[2])
	}
}

func indexHandler(w http.ResponseWriter, r *http.Request) {
	l, err := ReadDirNumSortToJSON(*datadir, false)
	if err != nil {
  	http.Error(w, err.Error(), http.StatusInternalServerError)
    return
	}
	renderIndexTemplate(w, "index.html", l)
}

func viewHandler(w http.ResponseWriter, r *http.Request, title string) {
  p, err := loadPage(title)
  if err != nil {
    http.Redirect(w, r, "/edit/"+title, http.StatusFound)
    return
  }
	renderTemplate(w, "view.html", p)
}

func editHandler(w http.ResponseWriter, r *http.Request, title string) {
	p, err := loadPage(title)
	if err != nil {
		p = &Page{Title: title}
	}
	renderTemplate(w, "edit.html", p)
}

func saveHandler(w http.ResponseWriter, r *http.Request, title string) {
  body := r.FormValue("body")
  p := &Page{Title: title, Body: []byte(body)}
  err := p.save()
  if err != nil {
      http.Error(w, err.Error(), http.StatusInternalServerError)
      return
  }
  http.Redirect(w, r, "/view/"+title, http.StatusFound)
}

type Page struct {
	Title string
	Body []byte
}

type FileInfo struct {
    Name    string
    Size    int64
    Mode    os.FileMode
    ModTime time.Time
    IsDir   bool
}

func (p *Page) save() error {
	filename := *datadir + "/" + p.Title
	return ioutil.WriteFile(filename, p.Body, 0600)
}

/* Indexing */
func ReadDirNumSort(dirname string, reverse bool) ([]os.FileInfo, error) {
    f, err := os.Open(dirname)
    if err != nil {
        return nil, err
    }
    list, err := f.Readdir(-1)
    f.Close()
    if err != nil {
        return nil, err
    }
    if reverse {
        sort.Sort(sort.Reverse(byName(list)))
    } else {
        sort.Sort(byName(list))
    }
    return list, nil
}

func ReadDirNumSortToJSON(dirname string, reverse bool) ([]FileInfo, error) {
    f, err := os.Open(dirname)
    if err != nil {
        return nil, err
    }
    list, err := f.Readdir(-1)
    f.Close()
    if err != nil {
        return nil, err
    }
    if reverse {
        sort.Sort(sort.Reverse(byName(list)))
    } else {
        sort.Sort(byName(list))
    }
    
    jlist := []FileInfo{}
    
    for _, entry := range list {
      f := FileInfo{
        Name: entry.Name(),
        Size: entry.Size(),
        Mode: entry.Mode(),
        ModTime: entry.ModTime(),
        IsDir: entry.IsDir(),
      }
      jlist = append(jlist, f)
    }
    /*output, err := json.Marshal(jlist)
    if err != nil {
      return nil, err
    }
    log.Println(string(output))*/
    return jlist, nil
}

// byName implements sort.Interface.
type byName []os.FileInfo

func (f byName) Len() int      { return len(f) }
func (f byName) Swap(i, j int) { f[i], f[j] = f[j], f[i] }
func (f byName) Less(i, j int) bool {
    nai, err := strconv.Atoi(f[i].Name())
    if err != nil {
        return f[i].Name() < f[j].Name()
    }
    naj, err := strconv.Atoi(f[j].Name())
    if err != nil {
        return f[i].Name() < f[j].Name()
    }
    return nai < naj
}
/* end Indexing */

func loadPage(title string) (*Page, error) {
	filename := *datadir + "/" + title
	body, err := ioutil.ReadFile(filename)
	if err != nil {
		return nil, err
	}
	return &Page{Title: title, Body: body}, nil
}

func main() {
  flag.Parse()
  http.HandleFunc("/", indexHandler)
	http.HandleFunc("/view/", makeHandler(viewHandler))
	http.HandleFunc("/edit/", makeHandler(editHandler))
	http.HandleFunc("/save/", makeHandler(saveHandler))
	
	http.ListenAndServe(":" + *httpport, nil)
}{% endraw %}