This is an OCaml implementation of the oEmbed standard [1]. Feel free to use it
however you'd like. A brief list of features:

* Send and receive oEmbed responses
* embed.ly [2] support baked in
* Decoupled from the network layer, so you can use your favorite HTTP library
  or asychronous I/O
* Supports JSON encoding (via `json-wheel`) and XML encoding (via `xml-light`)
* Obeys Postel's law; type-safe
* `ocamldoc` documentation
* Tiny, under 250 source lines of code
* BSD licensed

Enjoy!

[1]: http://oembed.com/
[2]: http://embed.ly/

