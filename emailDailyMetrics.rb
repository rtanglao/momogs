#!/usr/bin/env ruby
t = Time.now
mm = t.month.to_s
yyyy = t.year.to_s
dd = t.day.to_s
start_date = yyyy + mm + dd
start_date_str = yyyy  + " " + mm + " " + dd

end_date = start_date
end_date_str = start_date_str

stderrfile = 'emailReport.' + start_date + '.' + end_date + '.stderr'
stdoutfile = 'emailReport.' + start_date + '.' + end_date + '.stdout'
`./emailReport-m.rb #{start_date_str} #{end_date_str} 2>#{stderrfile} 1>#{stdoutfile}`
