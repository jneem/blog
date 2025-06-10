set datafile separator ","
set terminal pngcairo size 800,600 enhanced font 'Verdana,10'
set output 'timings.png'

set title "Execution time breakdown"
set xlabel "Size"
set ylabel "Time (ms)"
set style data histogram
set style histogram rowstacked
set style fill solid border -1
set boxwidth 0.75
set key outside

set xtics rotate by -45

plot 'timings.csv' using 2:xtic(1) title 'Creation', \
                  '' using 3 title 'Loading', \
                  '' using 4 title 'Dispatch'
