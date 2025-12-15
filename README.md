Command line app to create a weight-graph pdf.

Creates a land-scape mode, 8.5x11" paper for tracking weight.


Example usage:
```
dart run bin/weight_graph.dart -w 182
```

Full help:
```
dart run bin/weight_graph.dart --help                        
Usage: dart weight_graph.dart [options]

Generates a PDF weight tracking graph.

-h, --help            Print this usage information.
    --version         Print the tool version.
-l, --lines           Number of lines per inch.
                      (defaults to "10")
-m, --margin          Margin size in inches.
                      (defaults to "0.25")
-o, --output          Output file path.
                      (defaults to "graph_paper.pdf")
-w, --top-weight      Top weight value on Y-axis.
                      (defaults to "180")
-r, --weight-range    Total pounds to display (down from top weight).
                      (defaults to "32")
```