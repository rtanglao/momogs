#!/usr/bin/env ruby
start_date = ARGV[0] + ARGV[1] + ARGV[2]
start_date_str = ARGV[0] + " " + ARGV[1] + " " + ARGV[2]

end_date = ARGV[3] + ARGV[4] + ARGV[5]
end_date_str = ARGV[3] + " " + ARGV[4] + " " + ARGV[5]

stderrfile = 'getactive.' + start_date + '.' + end_date + '.stderr'
stdoutfile = 'getactive.' + start_date + '.' + end_date + '.stdout'
`./getactive-m.rb #{start_date_str} #{end_date_str} 2>#{stderrfile} 1>#{stdoutfile}`
stderrfile = 'gethappy.' + start_date + '.' + end_date + '.stderr'
stdoutfile = 'gethappy.' + start_date + '.' + end_date + '.stdout'
`./gethappykludged-m.rb #{start_date_str} #{end_date_str} 2>#{stderrfile} 1>#{stdoutfile}`
stderrfile = 'getresolved' + start_date + '.' + end_date + '.stderr'
stdoutfile = 'getresolved.' + start_date + '.' + end_date + '.stdout'
`./getNumCreatedNumResolved-m.rb #{start_date_str} #{end_date_str} 2>#{stderrfile} 1>#{stdoutfile}`

