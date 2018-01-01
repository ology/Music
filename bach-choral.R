# https://archive.ics.uci.edu/ml/datasets/Bach+Choral+Harmony

df <- read.table( file='~/Documents/data/jsbach_chorals_harmony/jsbach_chorals_harmony.data', sep=',', comment.char = '', strip.white = TRUE )

#names(df) <- c( 'id', 'event', 'C','C#','D','D#','E','F','F#','G','G#','A','A#','B', 'bass', 'velocity', 'chord' )

out <- split( df , f = df$V1 )

for ( i in  1:length(out) ) {
    name <- paste( '~/Documents/data/jsbach_chorals_harmony/bach-choral-', as.character(unique(out[[i]]$V1)), '.csv', sep='' )
    write.table( out[[i]], name, sep=',' )
}
