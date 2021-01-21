<!DOCTYPE html><html lang="en"><head><meta charset="utf-8"><title>Proposal: Monotonic Elapsed Time Measurements in Go</title><link rel="stylesheet" type="text/css" href="/+static/base.mkGYfyMw1ltYdSUJFnTfAQ.cache.css"/><link rel="stylesheet" type="text/css" href="/+static/doc.SwFWSqyOBtHwse7AqrZZeg.cache.css"/><link rel="stylesheet" type="text/css" href="/+static/prettify/prettify.AOMOBqJIPcDq491E2ExAAw.cache.css"/><!-- default customHeadTagPart --></head><body class="Site"><header class="Site-header "><div class="Header"><div class="Header-title"></div></div></header><div class="Site-content Site-Content--markdown"><div class="Container"><div class="doc"><h1><a class="h" name="Proposal_Monotonic-Elapsed-Time-Measurements-in-Go" href="#Proposal_Monotonic-Elapsed-Time-Measurements-in-Go"><span></span></a><a class="h" name="proposal_monotonic-elapsed-time-measurements-in-go" href="#proposal_monotonic-elapsed-time-measurements-in-go"><span></span></a>Proposal: Monotonic Elapsed Time Measurements in Go</h1><p>Author: Russ Cox</p><p>Last updated: January 26, 2017<br /> Discussion: <a href="https://golang.org/issue/12914">https://golang.org/issue/12914</a>.<br /> URL: <a href="https://golang.org/design/12914-monotonic">https://golang.org/design/12914-monotonic</a></p><h2><a class="h" name="Abstract" href="#Abstract"><span></span></a><a class="h" name="abstract" href="#abstract"><span></span></a>Abstract</h2><p>Comparison and subtraction of times observed by <code class="code">time.Now</code> can return incorrect results if the system wall clock is reset between the two observations. We propose to extend the <code class="code">time.Time</code> representation to hold an additional monotonic clock reading for use in those calculations. Among other benefits, this should make it impossible for a basic elapsed time measurement using <code class="code">time.Now</code> and <code class="code">time.Since</code> to report a negative duration or other result not grounded in reality.</p><h2><a class="h" name="Background" href="#Background"><span></span></a><a class="h" name="background" href="#background"><span></span></a>Background</h2><h3><a class="h" name="Clocks" href="#Clocks"><span></span></a><a class="h" name="clocks" href="#clocks"><span></span></a>Clocks</h3><p>A clock never keeps perfect time. Eventually, someone notices, decides the accumulated error—compared to a reference clock deemed more reliable—is large enough to be worth fixing, and resets the clock to match the reference. As I write this, the watch on my wrist is 44 seconds ahead of the clock on my computer. Compared to the computer, my watch gains about five seconds a day. In a few days I will probably be bothered enough to reset it to match the computer.</p><p>My watch may not be perfect for identifying the precise moment when a meeting should begin, but it&#39;s quite good for measuring elapsed time. If I start timing an event by checking the time, and then I stop timing the event by checking again and subtracting the two times, the error contributed by the watch speed will be under 0.01%.</p><p>Resetting a clock makes it better for telling time but useless, in that moment, for measuring time. If I reset my watch to match my computer while I am timing an event, the time of day it shows is now more accurate, but subtracting the start and end times for the event will produce a measurement that includes the reset. If I turn my watch back 44 seconds while timing a 60-second event, I would (unless I correct for the reset) measure the event as taking 16 seconds. Worse, I could measure a 10-second event as taking −34 seconds, ending before it began.</p><p>Since I know the watch is consistently gaining five seconds per day, I could reduce the need for resets by taking it to a watchmaker to adjust the mechanism to tick ever so slightly slower. I could also reduce the size of the resets by doing them more often. If, five times a day at regular intervals, I stopped my watch for one second, I wouldn&#39;t ever need a 44-second reset, reducing the maximum possible error introduced in the timing of an event. Similarly, if instead my watch lost five seconds each day, I could turn it forward one second five times a day to avoid larger forward resets.</p><h3><a class="h" name="Computer-clocks" href="#Computer-clocks"><span></span></a><a class="h" name="computer-clocks" href="#computer-clocks"><span></span></a>Computer clocks</h3><p>All the same problems affect computer clocks, usually with smaller time units.</p><p>Most computers have some kind of high-precision clock and a way to convert ticks of that clock to an equivalent number of seconds. Often, software on the computer compares that clock to a higher-accuracy reference clock <a href="https://tools.ietf.org/html/rfc5905">accessed over the network</a>. If the local clock is observed to be slightly ahead, it can be slowed a little by dropping an occasional tick; if slightly behind, sped up by counting some ticks twice. If the local clock is observed to run at a consistent speed relative to the reference clock (for example, five seconds fast per day), the software can change the conversion formula, making the slight corrections less frequent. These minor adjustments, applied regularly, can keep the local clock matched to the reference clock without observable resets, giving the outward appearance of a perfectly synchronized clock.</p><p>Unfortunately, many systems fall short of this appearance of perfection, for two main reasons.</p><p>First, some computer clocks are unreliable or don&#39;t run at all when the computer is off. The time starts out very wrong. After learning the correct time from the network, the only correction option is a reset.</p><p>Second, most computer time representations ignore leap seconds, in part because leap seconds—unlike leap years—follow no predictable pattern: the <a href="https://en.wikipedia.org/wiki/Leap_second">IERS decides about six months in advance</a> whether to insert (or in theory remove) a leap second at the end of a particular calendar month. In the real world, the leap second 23:59:60 UTC is inserted between 23:59:59 UTC and 00:00:00 UTC. Most computers, unable to represent 23:59:60, instead insert a clock reset and repeat 23:59:59.</p><p>Just like my watch, resetting a computer clock makes it better for telling time but useless, in that moment, for measuring time. Entering a leap second, the clock might report 23:59:59.995 at one instant and then report 23:59:59.005 ten milliseconds later; subtracting these to compute elapsed time results in −990 ms instead of +10 ms.</p><p>To avoid the problem of measuring elapsed times across clock resets, operating systems provide access to two different clocks: a wall clock and a monotonic clock. Both are adjusted to move forward at a target rate of one clock second per real second, but the monotonic clock starts at an undefined absolute value and is never reset. The wall clock is for telling time; the monotonic clock is for measuring time.</p><p>C/C++ programs use the operating system-provided mechanisms for querying one clock or the other. Java&#39;s <a href="https://docs.oracle.com/javase/8/docs/api/java/lang/System.html#nanoTime--"><code class="code">System.nanoTime</code></a> is widely believed to read a monotonic clock where available, returning an int64 counting nanoseconds since an arbitrary start point. Python 3.3 added monotonic clock support in <a href="https://www.python.org/dev/peps/pep-0418/">PEP 418</a>. The new function <code class="code">time.monotonic</code> reads the monotonic clock, returning a float64 counting seconds since an arbitrary start point; the old function <code class="code">time.time</code> reads the system wall clock, returning a float64 counting seconds since 1970.</p><h3><a class="h" name="Go-time" href="#Go-time"><span></span></a><a class="h" name="go-time" href="#go-time"><span></span></a>Go time</h3><p>Go&#39;s current <a href="https://golang.org/pkg/time/">time API</a>, which Rob Pike and I designed in 2011, defines an opaque type <code class="code">time.Time</code>, a function <code class="code">time.Now</code> that returns the current time, and a method <code class="code">t.Sub(u)</code> to subtract two times, along with other methods interpreting a <code class="code">time.Time</code> as a wall clock time. These are widely used by Go programs to measure elapsed times. The implementation of these functions only reads the system wall clock, never the monotonic clock, making the measurements incorrect in the event of clock resets.</p><p>Go&lsquo;s original target was Google&rsquo;s production servers, on which the wall clock never resets: the time is set very early in system startup, before any Go software runs, and leap seconds are handled by a <a href="https://developers.google.com/time/smear#standardsmear">leap smear</a>, spreading the extra second over a 20-hour window in which the clock runs at 99.9986% speed (20 hours on that clock corresponds to 20 hours and one second in the real world). In 2011, I hoped that the trend toward reliable, reset-free computer clocks would continue and that Go programs could safely use the system wall clock to measure elapsed times. I was wrong. Although Akamai, Amazon, and Microsoft use leap smears now too, many systems still implement leap seconds by clock reset. A Go program measuring a negative elapsed time during a leap second caused <a href="https://blog.cloudflare.com/how-and-why-the-leap-second-affected-cloudflare-dns/">CloudFlare&#39;s recent DNS outage</a>. Wikipedia&lsquo;s <a href="https://en.wikipedia.org/wiki/Leap_second#Examples_of_problems_associated_with_the_leap_second">list of examples of problems associated with the leap second</a> now includes CloudFlare&rsquo;s outage and notes Go&#39;s time APIs as the root cause. Beyond the problem of leap seconds, Go has also expanded to systems in non-production environments that may have less well-regulated clocks and consequently more frequent clock resets. Go must handle clock resets gracefully.</p><p>The internals of both the Go runtime and the Go time package originally used wall time but have already been converted as much as possible (without changing exported APIs) to use the monotonic clock. For example, if a goroutine runs <code class="code">time.Sleep(1*time.Minute)</code> and then the wall clock resets backward one hour, in the original Go implementation that goroutine would have slept for 61 real minutes. Today, that goroutine always sleeps for only 1 real minute. All other time APIs using <code class="code">time.Duration</code>, such as <code class="code">time.After</code>, <code class="code">time.Tick</code>, and <code class="code">time.NewTimer</code>, have similarly been converted to implement those durations using the monotonic clock.</p><p>Three standard Go APIs remain that use the system wall clock that should more properly use the monotonic clock. Due to <a href="https://golang.org/doc/go1compat">Go 1 compatibility</a>, the types and method names used in the APIs cannot be changed.</p><p>The first problematic Go API is measurement of elapsed times. Much code exists that uses patterns like:</p><pre class="code">start := time.Now()
... something ...
end := time.Now()
elapsed := start.Sub(end)
</pre><p>or, equivalently:</p><pre class="code">start := time.Now()
... something ...
elapsed := time.Since(start)
</pre><p>Because today <code class="code">time.Now</code> reads the wall clock, those measurements are wrong if the wall clock resets between calls, as happened at CloudFlare.</p><p>The second problematic Go API is network connection timeouts. Originally, the <code class="code">net.Conn</code> interface included methods to set timeouts in terms of durations:</p><pre class="code">type Conn interface {
	...
	SetTimeout(d time.Duration)
	SetReadTimeout(d time.Duration)
	SetWriteTimeout(d time.Duration)
}
</pre><p>This API confused users: it wasn&#39;t clear whether the duration measurement began when the timeout was set or began anew at each I/O operation. That is, if you call <code class="code">SetReadTimeout(100*time.Millisecond)</code>, does every <code class="code">Read</code> call wait 100ms before timing out, or do all <code class="code">Read</code>s simply stop working 100ms after the call to <code class="code">SetReadTimeout</code>? To avoid this confusion, we changed and renamed the APIs for Go 1 to use deadlines represented as <code class="code">time.Time</code>s:</p><pre class="code">type Conn interface {
	...
	SetDeadline(t time.Time)
	SetReadDeadline(t time.Time)
	SetWriteDeadline(t time.Time)
}
</pre><p>These are almost always invoked by adding a duration to the current time, as in <code class="code">c.SetDeadline(time.Now().Add(5*time.Second))</code>, which is longer but clearer than <code class="code">SetTimeout(5*time.Second)</code>.</p><p>Internally, the standard implementations of <code class="code">net.Conn</code> implement deadlines by converting the wall clock time to monotonic clock time immediately. In the call <code class="code">c.SetDeadline(time.Now().Add(5*time.Second))</code>, the deadline exists in wall clock form only for the hundreds of nanoseconds between adding the current wall clock time while preparing the argument and subtracting it again at the start of <code class="code">SetDeadline</code>. Even so, if the system wall clock resets during that tiny window, the deadline will be extended or contracted by the reset amount, resulting in possible hangs or spurious timeouts.</p><p>The third problematic Go API is <a href="https://golang.org/pkg/context/#Context">context deadlines</a>. The <code class="code">context.Context</code> interface defines a method that returns a <code class="code">time.Time</code>:</p><pre class="code">type Context interface {
	Deadline() (deadline time.Time, ok bool)
	...
}
</pre><p>Context uses a time instead of a duration for much the same reasons as <code class="code">net.Conn</code>: the returned deadline may be stored and consulted occasionally, and using a fixed <code class="code">time.Time</code> makes those later consultations refer to a fixed instant instead of a floating one.</p><p>In addition to these three standard APIs, there are any number of APIs outside the standard library that also use <code class="code">time.Time</code>s in similar ways. For example a common metrics collection package encourages users to time functions by:</p><pre class="code">defer metrics.MeasureSince(description, time.Now())
</pre><p>It seems clear that Go must better support computations involving elapsed times, including checking deadlines: wall clocks do reset and cause problems on systems where Go runs.</p><p>A survey of existing Go usage suggests that about 30% of the calls to <code class="code">time.Now</code> (by source code appearance, not dynamic call count) are used for measuring elapsed time and should use the system monotonic clock. Identifying and fixing all of these would be a large undertaking, as would developer education to correct future uses.</p><h2><a class="h" name="Proposal" href="#Proposal"><span></span></a><a class="h" name="proposal" href="#proposal"><span></span></a>Proposal</h2><p>For both backwards compatibility and API simplicity, we propose not to introduce any new API in the time package exposing the idea of monotonic clocks.</p><p>Instead, we propose to change <code class="code">time.Time</code> to store both a wall clock reading and an optional, additional monotonic clock reading; to change <code class="code">time.Now</code> to read both clocks and return a <code class="code">time.Time</code> containing both readings; to change <code class="code">t.Add(d)</code> to return a <code class="code">time.Time</code> in which both readings (if present) have been adjusted by <code class="code">d</code>; and to change <code class="code">t.Sub(u)</code> to operate on monotonic clock times when both <code class="code">t</code> and <code class="code">u</code> have them. In this way, developers keep using <code class="code">time.Now</code> always, leaving the implementation to follow the rule: use the wall clock for telling time, the monotonic clock for measuring time.</p><p>More specifically, we propose to make these changes to the <a href="https://golang.org/pkg/time/">package time documentation</a>, along with corresponding changes to the implementation.</p><p>Add this paragraph to the end of the <code class="code">time.Time</code> documentation:</p><blockquote><p>In addition to the required “wall clock” reading, a Time may contain an optional reading of the current process&#39;s monotonic clock, to provide additional precision for comparison or subtraction. See the “Monotonic Clocks” section in the package documentation for details.</p></blockquote><p>Add this section to the end of the package documentation:</p><blockquote><p>Monotonic Clocks</p><p>Operating systems provide both a “wall clock,” which is subject to resets for clock synchronization, and a “monotonic clock,” which is not. The general rule is that the wall clock is for telling time and the monotonic clock is for measuring time. Rather than split the API, in this package the Time returned by time.Now contains both a wall clock reading and a monotonic clock reading; later time-telling operations use the wall clock reading, but later time-measuring operations, specifically comparisons and subtractions, use the monotonic clock reading.</p><p>For example, this code always computes a positive elapsed time of approximately 20 milliseconds, even if the wall clock is reset during the operation being timed:</p><pre class="code">start := time.Now()
... operation that takes 20 milliseconds ...
t := time.Now()
elapsed := t.Sub(start)
</pre><p>Other idioms, such as time.Since(start), time.Until(deadline), and time.Now().Before(deadline), are similarly robust against wall clock resets.</p><p>The rest of this section gives the precise details of how operations use monotonic clocks, but understanding those details is not required to use this package.</p><p>The Time returned by time.Now contains a monotonic clock reading. If Time t has a monotonic clock reading, t.Add(d), t.Round(d), or t.Truncate(d) adds the same duration to both the wall clock and monotonic clock readings to compute the result. Similarly, t.In(loc), t.Local(), or t.UTC(), which are defined to change only the Time&#39;s Location, pass any monotonic clock reading through unmodified. Because t.AddDate(y, m, d) is a wall time computation, it always strips any monotonic clock reading from its result.</p><p>If Times t and u both contain monotonic clock readings, the operations t.After(u), t.Before(u), t.Equal(u), and t.Sub(u) are carried out using the monotonic clock readings alone, ignoring the wall clock readings. (If either t or u contains no monotonic clock reading, these operations use the wall clock readings.)</p><p>Note that the Go == operator includes the monotonic clock reading in its comparison. If time values returned from time.Now and time values constructed by other means (for example, by time.Parse or time.Unix) are meant to compare equal when used as map keys, the times returned by time.Now must have the monotonic clock reading stripped, by setting t = t.AddDate(0, 0, 0). In general, prefer t.Equal(u) to t == u, since t.Equal uses the most accurate comparison available and correctly handles the case when only one of its arguments has a monotonic clock reading.</p></blockquote><h2><a class="h" name="Rationale" href="#Rationale"><span></span></a><a class="h" name="rationale" href="#rationale"><span></span></a>Rationale</h2><h3><a class="h" name="Design" href="#Design"><span></span></a><a class="h" name="design" href="#design"><span></span></a>Design</h3><p>The main design question is whether to overload <code class="code">time.Time</code> or to provide a separate API for accessing the monotonic clock.</p><p>Most other systems provide separate APIs to read the wall clock and the monotonic clock, leaving the developer to decide between them at each use, hopefully by applying the rule stated above: “The wall clock is for telling time. The monotonic clock is for measuring time.”</p><p>if a developer uses a wall clock to measure time, that program will work correctly, almost always, except in the rare event of a clock reset. Providing two APIs that behave the same 99% of the time makes it very easy (and likely) for a developer to write a program that fails only rarely and not notice.</p><p>It gets worse. The program failures aren&lsquo;t random, like a race condition: they&rsquo;re caused by external events, namely clock resets. The most common clock reset in a well-run production setting is the leap second, which occurs simultaneously on all systems. When it does, all the copies of the program across the entire distributed system fail simultaneously, defeating any redundancy the system might have had.</p><p>So providing two APIs makes it very easy (and likely) for a developer to write programs that fail only rarely, but typically all at the same time.</p><p>This proposal instead treats the monotonic clock not as a new concept for developers to learn but instead as an implementation detail that can improve the accuracy of measuring time with the existing API. Developers don&lsquo;t need to learn anything new, and the obvious code just works. The implementation applies the rule; the developer doesn&rsquo;t have to think about it.</p><p>As noted earlier, a survey of existing Go usage (see Appendix below) suggests that about 30% of calls to <code class="code">time.Now</code> are used for measuring elapsed time and should use a monotonic clock. The same survey shows that all of those calls are fixed by this proposal, with no change in the programs themselves.</p><h3><a class="h" name="Simplicity" href="#Simplicity"><span></span></a><a class="h" name="simplicity" href="#simplicity"><span></span></a>Simplicity</h3><p>It is certainly simpler, in terms of implementation, to provide separate routines to read the wall clock and the monotonic clock and leave proper usage to developers. The API in this proposal is a bit more complex to specify and to implement but much simpler for developers to use.</p><p>No matter what, the effects of clock resets, especially leap seconds, can be counterintuitive.</p><p>Suppose a program starts just before a leap second:</p><pre class="code">t1 := time.Now()
... 10 ms of work
t2 := time.Now()
... 10 ms of work
t3 := time.Now()
... 10 ms of work
const f = &quot;15:04:05.000&quot;
fmt.Println(t1.Format(f), t2.Sub(t1), t2.Format(f), t3.Sub(t2), t3.Format(f))
</pre><p>In Go 1.8, the program can print:</p><pre class="code">23:59:59.985 10ms 23:59:59.995 -990ms 23:59:59.005
</pre><p>In the design proposed above, the program instead prints:</p><pre class="code">23:59:59.985 10ms 23:59:59.995 10ms 23:59:59.005
</pre><p>Although in both cases the second elapsed time requires some explanation, I&#39;d rather explain 10ms than −990ms. Most importantly, the actual time elapsed between the t2 and t3 calls to <code class="code">time.Now</code> really is 10 milliseconds.</p><p>In this case, 23:59:59.005 minus 23:59:59.995 can be 10 milliseconds, even though the printed times would suggest −990ms, because the printed time is incomplete.</p><p>The printed time is incomplete in other settings too. Suppose a program starts just before noon, printing only hours and minutes:</p><pre class="code">t1 := time.Now()
... 10 ms of work
t2 := time.Now()
... 10 ms of work
t3 := time.Now()
... 10 ms of work
const f = &quot;15:04&quot;
fmt.Println(t1.Format(f), t2.Sub(t1), t2.Format(f), t3.Sub(t2), t3.Format(f))
</pre><p>In Go 1.8, the program can print:</p><pre class="code">11:59 10ms 11:59 10ms 12:00
</pre><p>This is easily understood, even though the printed times indicate durations of 0 and 1 minute. The printed time is incomplete: it omits second and subsecond resolution.</p><p>Suppose instead that the program starts just before a 1am daylight savings shift. In Go 1.8, the program can print:</p><pre class="code">00:59 10ms 00:59 10ms 02:00
</pre><p>This too is easily understood, even though the printed times indicate durations of 0 and 61 minutes. The printed time is incomplete: it omits the time zone.</p><p>In the original example, printing 10ms instead of −990ms. The printed time is incomplete: it omits clock resets.</p><p>The Go 1.8 time representation makes correct time calculations across time zone changes by storing a time unaffected by time zone changes, along with additional information used for printing the time. Similarly, the proposed new time representation makes correct time calculations across clock resets by storing a time unaffected by clock resets (the monotonic clock reading), along with additional information used for printing the time (the wall clock reading).</p><h2><a class="h" name="Compatibility" href="#Compatibility"><span></span></a><a class="h" name="compatibility" href="#compatibility"><span></span></a>Compatibility</h2><p><a href="https://golang.org/doc/go1compat">Go 1 compatibility</a> keeps us from changing any of the types in the APIs mentioned above. In particular, <code class="code">net.Conn</code>&#39;s <code class="code">SetDeadline</code> method must continue to take a <code class="code">time.Time</code>, and <code class="code">context.Context</code>&#39;s <code class="code">Deadline</code> method must continue to return one. We arrived at the current proposal due to these compatibility constraints, but as explained in the Rationale above, it may actually be the best choice anyway.</p><p>Also mentioned above, about 30% of calls to <code class="code">time.Now</code> are used for measuring elapsed time and would be affected by this proposal. In every case we&#39;ve examined (see Appendix below), the effect is to eliminate the possibility of incorrect measurement results due to clock resets. We have found no existing Go code that is broken by the improved measurements.</p><p>If the proposal is adopted, the implementation should be landed at the start of a <a href="https://golang.org/wiki/Go-Release-Cycle">release cycle</a>, to maximize the time in which to find unexpected compatibility problems.</p><h2><a class="h" name="Implementation" href="#Implementation"><span></span></a><a class="h" name="implementation" href="#implementation"><span></span></a>Implementation</h2><p>The implementation work in package time is fairly straightforward, since the runtime has already worked out access to the monotonic clock on (nearly) all supported operating systems.</p><h3><a class="h" name="Reading-the-clocks" href="#Reading-the-clocks"><span></span></a><a class="h" name="reading-the-clocks" href="#reading-the-clocks"><span></span></a>Reading the clocks</h3><p><strong>Precision</strong>: In general, operating systems provide different system operations to read the wall clock and the monotonic clock, so the implementation of <code class="code">time.Now</code> must read both in sequence. Time will advance between the calls, with the effect that even in the absence of clock resets, <code class="code">t.Sub(u)</code> (using monotonic clock readings) and <code class="code">t.AddDate(0,0,0).Sub(u)</code> (using wall clock readings) will differ slightly. Since both cases are subtracting times obtained <code class="code">time.Now</code>, both results are arguably correct: any discrepancy is necessarily less than the overhead of the calls to <code class="code">time.Now</code>. This discrepancy only arises if code actively looks for it, by doing the subtraction or comparison both ways. In the survey of extant Go code (see Appendix below), we found no such code that would detect this discrepancy.</p><p>On x86 systems, Linux, macOS, and Windows convey clock information to user processes by publishing a page of memory containing the coefficients for a formula converting the processor&#39;s time stamp counter to monotonic clock and to wall clock readings. A perfectly synchronized read of both clocks could be obtained in this case by doing a single read of the time stamp counter and applying both formulas to the same input. This is an option if we decide it is important to eliminate the discrepancy on commonly used systems. This would improve precision but again it is false precision beyond the actual accuracy of the calls.</p><p><strong>Overhead</strong>: There is obviously an overhead to having <code class="code">time.Now</code> read two system clocks instead of one. However, as just mentioned, the usual implementation of these operations does not typically enter the operating system kernel, making two calls still quite cheap. The same “simultaneous computation” we could apply for additional precision would also reduce the overhead.</p><h3><a class="h" name="Time-representation" href="#Time-representation"><span></span></a><a class="h" name="time-representation" href="#time-representation"><span></span></a>Time representation</h3><p>The current definition of a <code class="code">time.Time</code> is:</p><pre class="code">type Time struct {
	sec  int64     // seconds since Jan 1, year 1 00:00:00 UTC
	nsec int32     // nanoseconds, in [0, 999999999]
	loc  *Location // location, for minute, hour, month, day, year
}
</pre><p>To add the optional monotonic clock reading, we can change the representation to:</p><pre class="code">type Time struct {
	wall uint64    // wall time: 1-bit flag, 33-bit sec since 1885, 30-bit nsec
	ext  int64     // extended time information
	loc  *Location // location
}
</pre><p>The wall field can encode the wall time, packed into a 33-bit seconds and 30-bit nsecs (keeping them separate avoids costly divisions). 233 seconds is 272 years, so the wall field by itself can encode times from the years 1885 to 2157 to nanosecond precision. If the top flag bit in <code class="code">t.wall</code> is set, then the wall seconds are packed into <code class="code">t.wall</code> as just described, and <code class="code">t.ext</code> holds a monotonic clock reading, stored as nanoseconds since Go process startup (translating to process start ensures we can store monotonic clock readings even if the operating system returns a representation larger than 64 bits). Otherwise (the top flag bit is clear), the 33-bit field in <code class="code">t.wall</code> must be zero, and <code class="code">t.ext</code> holds the full 64-bit seconds since Jan 1, year 1, as in the original Time representation. Note that the meaning of the zero Time is unchanged.</p><p>An implication is that monotonic clock readings can only be stored alongside wall clock readings for the years 1885 to 2157. We only need to store monotonic clock readings in the result of <code class="code">time.Now</code> and derived nearby times, and we expect those times to lie well within the range 1885 to 2157. The low end of the range is constrained by the default boot time used on a system with a dead clock: in this common case, we must be able to store a monotonic clock reading alongside the wall clock reading. Unix-based systems often use 1970, and Windows-based systems often use 1980. We are unaware of any systems using earlier default wall times, but since the NTP protocol epoch uses 1900, it seemed more future-proof to choose a year before 1900.</p><p>On 64-bit systems, there is a 32-bit padding gap between <code class="code">nsec</code> and <code class="code">loc</code> in the current representation, which the new representation fills, keeping the overall struct size at 24 bytes. On 32-bit systems, there is no such gap, and the overall struct size grows from 16 to 20 bytes.</p><h1><a class="h" name="Appendix_time_Now-usage" href="#Appendix_time_Now-usage"><span></span></a><a class="h" name="appendix_time_now-usage" href="#appendix_time_now-usage"><span></span></a>Appendix: time.Now usage</h1><p>We analyzed uses of time.Now in <a href="https://github.com/rsc/corpus">Go Corpus v0.01</a>.</p><p>Overall estimates:</p><ul><li>71% unaffected</li><li>29% fixed in event of wall clock time warps (subtractions or comparisons)</li></ul><p>Basic counts:</p><pre class="code">$ cg -f $(pwd)&#39;.*\.go$&#39; &#39;time\.Now\(\)&#39; | sed &#39;s;//.*;;&#39; |grep time.Now &gt;alltimenow
$ wc -l alltimenow
   16569 alltimenow
$ egrep -c &#39;time\.Now\(\).*time\.Now\(\)&#39; alltimenow
63

$ 9 sed -n &#39;s/.*(time\.Now\(\)(\.[A-Za-z0-9]+)?).*/\1/p&#39; alltimenow | sort | uniq -c
4910 time.Now()
1511 time.Now().Add
  45 time.Now().AddDate
  69 time.Now().After
  77 time.Now().Before
   4 time.Now().Date
   5 time.Now().Day
   1 time.Now().Equal
 130 time.Now().Format
  23 time.Now().In
   8 time.Now().Local
   4 time.Now().Location
   1 time.Now().MarshalBinary
   2 time.Now().MarshalText
   2 time.Now().Minute
  68 time.Now().Nanosecond
  14 time.Now().Round
  22 time.Now().Second
  37 time.Now().String
 370 time.Now().Sub
  28 time.Now().Truncate
 570 time.Now().UTC
 582 time.Now().Unix
8067 time.Now().UnixNano
  17 time.Now().Year
   2 time.Now().Zone
</pre><p>That splits into completely unaffected:</p><pre class="code">  45 time.Now().AddDate
   4 time.Now().Date
   5 time.Now().Day
 130 time.Now().Format
  23 time.Now().In
   8 time.Now().Local
   4 time.Now().Location
   1 time.Now().MarshalBinary
   2 time.Now().MarshalText
   2 time.Now().Minute
  68 time.Now().Nanosecond
  14 time.Now().Round
  22 time.Now().Second
  37 time.Now().String
  28 time.Now().Truncate
 570 time.Now().UTC
 582 time.Now().Unix
8067 time.Now().UnixNano
  17 time.Now().Year
   2 time.Now().Zone
9631 TOTAL
</pre><p>and possibly affected:</p><pre class="code">4910 time.Now()
1511 time.Now().Add
  69 time.Now().After
  77 time.Now().Before
   1 time.Now().Equal
 370 time.Now().Sub
6938 TOTAL
</pre><p>If we pull out the possibly affected lines, the overall count is slightly higher because of the 63 lines with more than one time.Now call:</p><pre class="code">$ egrep &#39;time\.Now\(\)([^.]|\.(Add|After|Before|Equal|Sub)|$)&#39; alltimenow &gt;checktimenow
$ wc -l checktimenow
    6982 checktimenow
</pre><p>From the start, then, 58% of time.Now uses immediately flip to wall time and are unaffected. The remaining 42% may be affected.</p><p>Randomly sampling 100 of the 42%, we find:</p><ul><li>32 unaffected (23 use wall time once; 9 use wall time multiple times)</li><li>68 fixed</li></ul><p>We estimate therefore that the 42% is made up of 13% additional unaffected and 29% fixed, giving an overall total of 71% unaffected, 29% fixed.</p><h2><a class="h" name="Unaffected" href="#Unaffected"><span></span></a><a class="h" name="unaffected" href="#unaffected"><span></span></a>Unaffected</h2><h3><a class="h" name="github_com_mitchellh_packer_vendor_google_golang_org_appengine_demos_guestbook_guestbook_go_97" href="#github_com_mitchellh_packer_vendor_google_golang_org_appengine_demos_guestbook_guestbook_go_97"><span></span></a>github.com/mitchellh/packer/vendor/google.golang.org/appengine/demos/guestbook/guestbook.go:97</h3><pre class="code">func handleSign(w http.ResponseWriter, r *http.Request) {
	...
	g := &amp;Greeting{
		Content: r.FormValue(&quot;content&quot;),
		Date:    time.Now(),
	}
	... datastore.Put(ctx, key, g) ...
}
</pre><p><strong>Unaffected.</strong> The time will be used exactly once, during the serialization of g.Date in datastore.Put.</p><h3><a class="h" name="github_com_aws_aws_sdk_go_service_databasemigrationservice_examples_test_go_887" href="#github_com_aws_aws_sdk_go_service_databasemigrationservice_examples_test_go_887"><span></span></a>github.com/aws/aws-sdk-go/service/databasemigrationservice/examples_test.go:887</h3><pre class="code">func ExampleDatabaseMigrationService_ModifyReplicationTask() {
	...
	params := &amp;databasemigrationservice.ModifyReplicationTaskInput{
		...
		CdcStartTime:              aws.Time(time.Now()),
		...
	}
	... svc.ModifyReplicationTask(params) ...
}
</pre><p><strong>Unaffected.</strong> The time will be used exactly once, during the serialization of params.CdcStartTime in svc.ModifyReplicationTask.</p><h3><a class="h" name="github_com_influxdata_telegraf_plugins_inputs_mongodb_mongodb_data_test_go_94" href="#github_com_influxdata_telegraf_plugins_inputs_mongodb_mongodb_data_test_go_94"><span></span></a>github.com/influxdata/telegraf/plugins/inputs/mongodb/mongodb_data_test.go:94</h3><pre class="code">d := NewMongodbData(
	&amp;StatLine{
		...
		Time:          time.Now(),
		...
	},
	...
)
</pre><p>StatLine.Time is commented as &quot;the time at which this StatLine was generated&#39;&#39; and is only used by passing to acc.AddFields, where acc is a telegraf.Accumulator.</p><pre class="code">// AddFields adds a metric to the accumulator with the given measurement
// name, fields, and tags (and timestamp). If a timestamp is not provided,
// then the accumulator sets it to &quot;now&quot;.
// Create a point with a value, decorating it with tags
// NOTE: tags is expected to be owned by the caller, don&#39;t mutate
// it after passing to Add.
AddFields(measurement string,
	fields map[string]interface{},
	tags map[string]string,
	t ...time.Time)
</pre><p>The non-test implementation of Accumulator calls t.Round, which will convert to wall time.</p><p><strong>Unaffected.</strong></p><h3><a class="h" name="github_com_spf13_fsync_fsync_test_go_23" href="#github_com_spf13_fsync_fsync_test_go_23"><span></span></a>github.com/spf13/fsync/fsync_test.go:23</h3><pre class="code">// set times in the past to make sure times are synced, not accidentally
// the same
tt := time.Now().Add(-1 * time.Hour)
check(os.Chtimes(&quot;src/a/b&quot;, tt, tt))
check(os.Chtimes(&quot;src/a&quot;, tt, tt))
check(os.Chtimes(&quot;src/c&quot;, tt, tt))
check(os.Chtimes(&quot;src&quot;, tt, tt))
</pre><p><strong>Unaffected.</strong></p><h3><a class="h" name="github_com_flynn_flynn_vendor_github_com_gorilla_handlers_handlers_go_66" href="#github_com_flynn_flynn_vendor_github_com_gorilla_handlers_handlers_go_66"><span></span></a>github.com/flynn/flynn/vendor/github.com/gorilla/handlers/handlers.go:66</h3><pre class="code">t := time.Now()
...
writeLog(h.writer, req, url, t, logger.Status(), logger.Size())
</pre><p>writeLog calls buildCommonLogLine, which eventually calls t.Format.</p><p><strong>Unaffected.</strong></p><h3><a class="h" name="github_com_ncw_rclone_vendor_google_golang_org_grpc_server_go_586" href="#github_com_ncw_rclone_vendor_google_golang_org_grpc_server_go_586"><span></span></a>github.com/ncw/rclone/vendor/google.golang.org/grpc/server.go:586</h3><pre class="code">if err == nil &amp;&amp; outPayload != nil {
	outPayload.SentTime = time.Now()
	stats.HandleRPC(stream.Context(), outPayload)
}
</pre><p>SentTime seems to never be used. Client code could call stats.RegisterRPCHandler to do stats processing and look at SentTime. Any use of time.Since(SentTime) would be improved by having SentTime be monotonic here.</p><p>There are no calls to stats.RegisterRPCHandler in the entire corpus.</p><p><strong>Unaffected.</strong></p><h3><a class="h" name="github_com_openshift_origin_vendor_github_com_influxdata_influxdb_models_points_go_1316" href="#github_com_openshift_origin_vendor_github_com_influxdata_influxdb_models_points_go_1316"><span></span></a>github.com/openshift/origin/vendor/github.com/influxdata/influxdb/models/points.go:1316</h3><pre class="code">func (p *point) UnmarshalBinary(b []byte) error {	
	...
	p.time = time.Now()
	p.time.UnmarshalBinary(b[i:])
	...
}
</pre><p>That&#39;s weird. It looks like it is setting p.time in case of an error in UnmarshalBinary, instead of checking for and propagating an error. All the other ways that a p.time is initalized end up using non-monotonic times, because they came from time.Unix or t.Round. Assuming that bad decodings are rare, going to call it unaffected.</p><p><strong>Unaffected</strong> (but not completely sure).</p><h3><a class="h" name="github_com_zyedidia_micro_cmd_micro_util_go" href="#github_com_zyedidia_micro_cmd_micro_util_go"><span></span></a>github.com/zyedidia/micro/cmd/micro/util.go</h3><pre class="code">// GetModTime returns the last modification time for a given file
// It also returns a boolean if there was a problem accessing the file
func GetModTime(path string) (time.Time, bool) {
	info, err := os.Stat(path)
	if err != nil {
		return time.Now(), false
	}
	return info.ModTime(), true
}
</pre><p>The result is recorded in the field Buffer.ModTime and then checked against future calls to GetModTime to see if the file changed:</p><pre class="code">// We should only use last time&#39;s eventhandler if the file wasn&#39;t by someone else in the meantime
if b.ModTime == buffer.ModTime {
	b.EventHandler = buffer.EventHandler
	b.EventHandler.buf = b
}
</pre><p>and</p><pre class="code">if modTime != b.ModTime {
	choice, canceled := messenger.YesNoPrompt(&quot;The file has changed since it was last read. Reload file? (y,n)&quot;)
	...
}
</pre><p>Normally Buffer.ModTime will be a wall time, but if the file doesn&lsquo;t exist Buffer.ModTime will be a monotonic time that will not compare == to any file time. That&rsquo;s the desired behavior here.</p><p><strong>Unaffected</strong> (or maybe fixed).</p><h3><a class="h" name="github_com_gravitational_teleport_lib_auth_init_test_go_59" href="#github_com_gravitational_teleport_lib_auth_init_test_go_59"><span></span></a>github.com/gravitational/teleport/lib/auth/init_test.go:59</h3><pre class="code">// test TTL by converting the generated cert to text -&gt; back and making sure ExpireAfter is valid
ttl := time.Second * 10
expiryDate := time.Now().Add(ttl)
bytes, err := t.GenerateHostCert(priv, pub, &quot;id1&quot;, &quot;example.com&quot;, teleport.Roles{teleport.RoleNode}, ttl)
c.Assert(err, IsNil)
pk, _, _, _, err := ssh.ParseAuthorizedKey(bytes)
c.Assert(err, IsNil)
copy, ok := pk.(*ssh.Certificate)
c.Assert(ok, Equals, true)
c.Assert(uint64(expiryDate.Unix()), Equals, copy.ValidBefore)
</pre><p>This is jittery, in the sense that the computed expiryDate may not exactly match the cert generation that—one must assume—grabs the current time and adds the passed ttl to it to compute ValidBefore. It&lsquo;s unclear without digging exactly how the cert gets generated (there seems to be an RPC, but I don&rsquo;t know if it&lsquo;s to a test server in the same process). Either way, the two times are only possibly equal because of the rounding to second granularity. Even today, if the call expiryDate := time.Now().Add(ttl) happens 1 nanosecond before a wall time second boundary, this test will fail. Moving to monotonic time will not change the fact that it&rsquo;s jittery.</p><p><strong>Unaffected.</strong></p><h3><a class="h" name="github_com_aws_aws_sdk_go_private_model_api_operation_go_420" href="#github_com_aws_aws_sdk_go_private_model_api_operation_go_420"><span></span></a>github.com/aws/aws-sdk-go/private/model/api/operation.go:420</h3><pre class="code">case &quot;timestamp&quot;:
	str = `aws.Time(time.Now())`
</pre><p>This is the example generator for the AWS documentation. An aws.Time is always just being put into a structure to send over the wire in JSON format to AWS, so these remain OK.</p><p><strong>Unaffected.</strong></p><h3><a class="h" name="github_com_influxdata_telegraf_plugins_inputs_mongodb_mongodb_data_test_go_17" href="#github_com_influxdata_telegraf_plugins_inputs_mongodb_mongodb_data_test_go_17"><span></span></a>github.com/influxdata/telegraf/plugins/inputs/mongodb/mongodb_data_test.go:17</h3><pre class="code">d := NewMongodbData(
	&amp;StatLine{
		...
		Time:             time.Now(),
		...
	},
	...
}
</pre><p><strong>Unaffected</strong> (see above from same file).</p><h3><a class="h" name="github_com_aws_aws_sdk_go_service_datapipeline_examples_test_go_36" href="#github_com_aws_aws_sdk_go_service_datapipeline_examples_test_go_36"><span></span></a>github.com/aws/aws-sdk-go/service/datapipeline/examples_test.go:36</h3><pre class="code">params := &amp;datapipeline.ActivatePipelineInput{
	...
	StartTimestamp: aws.Time(time.Now()),
}
resp, err := svc.ActivatePipeline(params)
</pre><p>The svc.ActivatePipeline call serializes StartTimestamp to JSON (just once).</p><p><strong>Unaffected.</strong></p><h3><a class="h" name="github_com_jessevdk_go_flags_man_go_177" href="#github_com_jessevdk_go_flags_man_go_177"><span></span></a>github.com/jessevdk/go-flags/man.go:177</h3><pre class="code">t := time.Now()
fmt.Fprintf(wr, &quot;.TH %s 1 \&quot;%s\&quot;\n&quot;, manQuote(p.Name), t.Format(&quot;2 January 2006&quot;))
</pre><p><strong>Unaffected.</strong></p><h3><a class="h" name="k8s_io_heapster_events_manager_manager_test_go_28" href="#k8s_io_heapster_events_manager_manager_test_go_28"><span></span></a>k8s.io/heapster/events/manager/manager_test.go:28</h3><pre class="code">batch := &amp;core.EventBatch{
	Timestamp: time.Now(),
	Events:    []*kube_api.Event{},
}
</pre><p>Later used as:</p><pre class="code">buffer.WriteString(fmt.Sprintf(&quot;EventBatch     Timestamp: %s\n&quot;, batch.Timestamp))
</pre><p><strong>Unaffected.</strong></p><h3><a class="h" name="k8s_io_heapster_metrics_storage_podmetrics_reststorage_go_121" href="#k8s_io_heapster_metrics_storage_podmetrics_reststorage_go_121"><span></span></a>k8s.io/heapster/metrics/storage/podmetrics/reststorage.go:121</h3><pre class="code">CreationTimestamp: unversioned.NewTime(time.Now())
</pre><p>But CreationTimestamp is only ever checked for being the zero time or not.</p><p><strong>Unaffected.</strong></p><h3><a class="h" name="github_com_revel_revel_server_go_46" href="#github_com_revel_revel_server_go_46"><span></span></a>github.com/revel/revel/server.go:46</h3><pre class="code">start := time.Now()
...
// Revel request access log format
// RequestStartTime ClientIP ResponseStatus RequestLatency HTTPMethod URLPath
// Sample format:
// 2016/05/25 17:46:37.112 127.0.0.1 200  270.157µs GET /
requestLog.Printf(&quot;%v %v %v %10v %v %v&quot;,
	start.Format(requestLogTimeFormat),
	ClientIP(r),
	c.Response.Status,
	time.Since(start),
	r.Method,
	r.URL.Path,
)
</pre><p><strong>Unaffected.</strong></p><h3><a class="h" name="github_com_hashicorp_consul_command_agent_agent_go_1426" href="#github_com_hashicorp_consul_command_agent_agent_go_1426"><span></span></a>github.com/hashicorp/consul/command/agent/agent.go:1426</h3><pre class="code">Expires: time.Now().Add(check.TTL).Unix(),
</pre><p><strong>Unaffected.</strong></p><h3><a class="h" name="github_com_drone_drone_server_login_go_143" href="#github_com_drone_drone_server_login_go_143"><span></span></a>github.com/drone/drone/server/login.go:143</h3><pre class="code">exp := time.Now().Add(time.Hour * 72).Unix()
</pre><p><strong>Unaffected.</strong></p><h3><a class="h" name="github_com_openshift_origin_vendor_github_com_coreos_etcd_pkg_transport_listener_go_113" href="#github_com_openshift_origin_vendor_github_com_coreos_etcd_pkg_transport_listener_go_113"><span></span></a>github.com/openshift/origin/vendor/github.com/coreos/etcd/pkg/transport/listener.go:113:</h3><pre class="code">tmpl := x509.Certificate{
	NotBefore:    time.Now(),
	NotAfter:     time.Now().Add(365 * (24 * time.Hour)),
	...
}
...
derBytes, err := x509.CreateCertificate(rand.Reader, &amp;tmpl, &amp;tmpl, &amp;priv.PublicKey, priv)
</pre><p><strong>Unaffected.</strong></p><h3><a class="h" name="github_com_ethereum_go_ethereum_swarm_api_http_server_go_189" href="#github_com_ethereum_go_ethereum_swarm_api_http_server_go_189"><span></span></a>github.com/ethereum/go-ethereum/swarm/api/http/server.go:189</h3><pre class="code">http.ServeContent(w, r, &quot;&quot;, time.Now(), bytes.NewReader([]byte(newKey)))
</pre><p>eventually uses the passed time in formatting:</p><pre class="code">w.Header().Set(&quot;Last-Modified&quot;, modtime.UTC().Format(TimeFormat))
</pre><p><strong>Unaffected.</strong></p><h3><a class="h" name="github_com_hashicorp_consul_vendor_google_golang_org_grpc_call_go_187" href="#github_com_hashicorp_consul_vendor_google_golang_org_grpc_call_go_187"><span></span></a>github.com/hashicorp/consul/vendor/google.golang.org/grpc/call.go:187</h3><pre class="code">if sh != nil {
	ctx = sh.TagRPC(ctx, &amp;stats.RPCTagInfo{FullMethodName: method})
	begin := &amp;stats.Begin{
		Client:    true,
		BeginTime: time.Now(),
		FailFast:  c.failFast,
	}
	sh.HandleRPC(ctx, begin)
}
defer func() {
	if sh != nil {
		end := &amp;stats.End{
			Client:  true,
			EndTime: time.Now(),
			Error:   e,
		}
		sh.HandleRPC(ctx, end)
	}
}()
</pre><p>If something subtracted BeginTime and EndTime, that would be fixed by monotonic times. I don&#39;t see any implementations of StatsHandler in the tree, though, so sh must be nil.</p><p><strong>Unaffected.</strong></p><h3><a class="h" name="github_com_hashicorp_vault_builtin_logical_pki_backend_test_go_396" href="#github_com_hashicorp_vault_builtin_logical_pki_backend_test_go_396"><span></span></a>github.com/hashicorp/vault/builtin/logical/pki/backend_test.go:396</h3><pre class="code">if !cert.NotBefore.Before(time.Now().Add(-10 * time.Second)) {
	return nil, fmt.Errorf(&quot;Validity period not far enough in the past&quot;)
}
</pre><p>cert.NotBefore is usually the result of decoding an wire format certificate, so it&#39;s not monotonic, so the time will collapse to wall time during the Before check.</p><p><strong>Unaffected.</strong></p><h3><a class="h" name="github_com_openshift_origin_vendor_k8s_io_kubernetes_plugin_pkg_admission_namespace_lifecycle_admission_test_go_194" href="#github_com_openshift_origin_vendor_k8s_io_kubernetes_plugin_pkg_admission_namespace_lifecycle_admission_test_go_194"><span></span></a>github.com/openshift/origin/vendor/k8s.io/kubernetes/plugin/pkg/admission/namespace/lifecycle/admission_test.go:194</h3><pre class="code">fakeClock := clock.NewFakeClock(time.Now())
</pre><p>The clock being implemented does Since, After, and other relative manipulation only.</p><p><strong>Unaffected.</strong></p><h2><a class="h" name="Unaffected-but-uses-time_Time-as-wall-time-multiple-times" href="#Unaffected-but-uses-time_Time-as-wall-time-multiple-times"><span></span></a><a class="h" name="unaffected-but-uses-time_time-as-wall-time-multiple-times" href="#unaffected-but-uses-time_time-as-wall-time-multiple-times"><span></span></a>Unaffected (but uses time.Time as wall time multiple times)</h2><p>These are split out because an obvious optimization would be to store just the monotonic time and rederive the wall time using the current wall-vs-monotonic correspondence from the operating system. Using a wall form multiple times in this case could show up as jitter. The proposal does <em>not</em> suggest this optimization, precisely because of cases like these.</p><h3><a class="h" name="github_com_docker_distribution_registry_storage_driver_inmemory_mfs_go_195" href="#github_com_docker_distribution_registry_storage_driver_inmemory_mfs_go_195"><span></span></a>github.com/docker/distribution/registry/storage/driver/inmemory/mfs.go:195</h3><pre class="code">// mkdir creates a child directory under d with the given name.
func (d *dir) mkdir(name string) (*dir, error) {
	... d.mod = time.Now() ...
}
</pre><p>ends up being used by</p><pre class="code">fi := storagedriver.FileInfoFields{
	Path:    path,
	IsDir:   found.isdir(),
	ModTime: found.modtime(),
}
</pre><p>which will result in that time being returned by an os.FileInfo implementation&#39;s ModTime method.</p><p><strong>Unaffected</strong> (but uses time multiple times).</p><h3><a class="h" name="github_com_minio_minio_cmd_server_startup_msg_test_go_52" href="#github_com_minio_minio_cmd_server_startup_msg_test_go_52"><span></span></a>github.com/minio/minio/cmd/server-startup-msg_test.go:52</h3><pre class="code">// given
var expiredDate = time.Now().Add(time.Hour * 24 * (30 - 1)) // 29 days.
var fakeCerts = []*x509.Certificate{
	... NotAfter: expiredDate ...
}

expectedMsg := colorBlue(&quot;\nCertificate expiry info:\n&quot;) +
	colorBold(fmt.Sprintf(&quot;#1 Test cert will expire on %s\n&quot;, expiredDate))

msg := getCertificateChainMsg(fakeCerts)
if msg != expectedMsg {
	t.Fatalf(&quot;Expected message was: %s, got: %s&quot;, expectedMsg, msg)
}
</pre><p><strong>Unaffected</strong> (but uses time multiple times).</p><h3><a class="h" name="github_com_pingcap_tidb_expression_builtin_string_test_go_42" href="#github_com_pingcap_tidb_expression_builtin_string_test_go_42"><span></span></a>github.com/pingcap/tidb/expression/builtin_string_test.go:42</h3><pre class="code">{types.Time{Time: types.FromGoTime(time.Now()), Fsp: 6, Type: mysql.TypeDatetime}, 26},
</pre><p>The call to FromGoTime does:</p><pre class="code">func FromGoTime(t gotime.Time) TimeInternal {
	year, month, day := t.Date()
	hour, minute, second := t.Clock()
	microsecond := t.Nanosecond() / 1000
	return newMysqlTime(year, int(month), day, hour, minute, second, microsecond)
}
</pre><p><strong>Unaffected</strong> (but uses time multiple times).</p><h3><a class="h" name="github_com_docker_docker_vendor_github_com_docker_distribution_registry_client_repository_go_750" href="#github_com_docker_docker_vendor_github_com_docker_distribution_registry_client_repository_go_750"><span></span></a>github.com/docker/docker/vendor/github.com/docker/distribution/registry/client/repository.go:750</h3><pre class="code">func (bs *blobs) Create(ctx context.Context, options ...distribution.BlobCreateOption) (distribution.BlobWriter, error) {
	...
	return &amp;httpBlobUpload{
		statter:   bs.statter,
		client:    bs.client,
		uuid:      uuid,
		startedAt: time.Now(),
		location:  location,
	}, nil
}
</pre><p>That field is used to implement distribution.BlobWriter interface&#39;s StartedAt method, which is eventually copied into a handlers.blobUploadState, which is sometimes serialized to JSON and reconstructed. The serialization seems to be the single use.</p><p><strong>Unaffected</strong> (but not completely sure about use count).</p><h3><a class="h" name="github_com_pingcap_pd_vendor_vendor_golang_org_x_net_internal_timeseries_timeseries_go_83" href="#github_com_pingcap_pd_vendor_vendor_golang_org_x_net_internal_timeseries_timeseries_go_83"><span></span></a>github.com/pingcap/pd/_vendor/vendor/golang.org/x/net/internal/timeseries/timeseries.go:83</h3><pre class="code">// A Clock tells the current time.
type Clock interface {
	Time() time.Time
}

type defaultClock int
var defaultClockInstance defaultClock
func (defaultClock) Time() time.Time { return time.Now() }
</pre><p>Let&#39;s look at how that gets used.</p><p>The main use is to get a now time and then check whether</p><pre class="code">if ts.levels[0].end.Before(now) {
	ts.advance(now)
}
</pre><p>but levels[0].end was rounded, meaning its a wall time. advance then does:</p><pre class="code">if !t.After(ts.levels[0].end) {
	return
}
for i := 0; i &lt; len(ts.levels); i++ {
	level := ts.levels[i]
	if !level.end.Before(t) {
		break
	}

	// If the time is sufficiently far, just clear the level and advance
	// directly.
	if !t.Before(level.end.Add(level.size * time.Duration(ts.numBuckets))) {
		for _, b := range level.buckets {
			ts.resetObservation(b)
		}
		level.end = time.Unix(0, (t.UnixNano()/level.size.Nanoseconds())*level.size.Nanoseconds())
	}

	for t.After(level.end) {
		level.end = level.end.Add(level.size)
		level.newest = level.oldest
		level.oldest = (level.oldest + 1) % ts.numBuckets
		ts.resetObservation(level.buckets[level.newest])
	}

	t = level.end
}
</pre><p><strong>Unaffected</strong> (but uses time multiple times).</p><h3><a class="h" name="github_com_astaxie_beego_logs_logger_test_go_24" href="#github_com_astaxie_beego_logs_logger_test_go_24"><span></span></a>github.com/astaxie/beego/logs/logger_test.go:24</h3><pre class="code">func TestFormatHeader_0(t *testing.T) {
	tm := time.Now()
	if tm.Year() &gt;= 2100 {
		t.FailNow()
	}
	dur := time.Second
	for {
		if tm.Year() &gt;= 2100 {
			break
		}
		h, _ := formatTimeHeader(tm)
		if tm.Format(&quot;2006/01/02 15:04:05 &quot;) != string(h) {
			t.Log(tm)
			t.FailNow()
		}
		tm = tm.Add(dur)
		dur *= 2
	}
}
</pre><p><strong>Unaffected</strong> (but uses time multiple times).</p><h3><a class="h" name="github_com_attic_labs_noms_vendor_github_com_aws_aws_sdk_go_aws_signer_v4_v4_test_go_418" href="#github_com_attic_labs_noms_vendor_github_com_aws_aws_sdk_go_aws_signer_v4_v4_test_go_418"><span></span></a>github.com/attic-labs/noms/vendor/github.com/aws/aws-sdk-go/aws/signer/v4/v4_test.go:418</h3><pre class="code">ctx := &amp;signingCtx{
	...
	Time:        time.Now(),
	ExpireTime:  5 * time.Second,
}

ctx.buildCanonicalString()
expected := &quot;https://example.org/bucket/key-._~,!@#$%^&amp;*()?Foo=z&amp;Foo=o&amp;Foo=m&amp;Foo=a&quot;
assert.Equal(t, expected, ctx.Request.URL.String())
</pre><p>ctx is used as:</p><pre class="code">ctx.formattedTime = ctx.Time.UTC().Format(timeFormat)
ctx.formattedShortTime = ctx.Time.UTC().Format(shortTimeFormat)
</pre><p>and then ctx.formattedTime is used sometimes and ctx.formattedShortTime is used other times.</p><p><strong>Unaffected</strong> (but uses time multiple times).</p><h3><a class="h" name="github_com_zenazn_goji_example_models_go_21" href="#github_com_zenazn_goji_example_models_go_21"><span></span></a>github.com/zenazn/goji/example/models.go:21</h3><pre class="code">var Greets = []Greet{
	{&quot;carl&quot;, &quot;Welcome to Gritter!&quot;, time.Now()},
	{&quot;alice&quot;, &quot;Wanna know a secret?&quot;, time.Now()},
	{&quot;bob&quot;, &quot;Okay!&quot;, time.Now()},
	{&quot;eve&quot;, &quot;I&#39;m listening...&quot;, time.Now()},
}
</pre><p>used by:</p><pre class="code">// Write out a representation of the greet
func (g Greet) Write(w io.Writer) {
	fmt.Fprintf(w, &quot;%s\n@%s at %s\n---\n&quot;, g.Message, g.User,
		g.Time.Format(time.UnixDate))
}
</pre><p><strong>Unaffected</strong> (but may use wall representation multiple times).</p><h3><a class="h" name="github_com_afex_hystrix_go_hystrix_rolling_rolling_timing_go_77" href="#github_com_afex_hystrix_go_hystrix_rolling_rolling_timing_go_77"><span></span></a>github.com/afex/hystrix-go/hystrix/rolling/rolling_timing.go:77</h3><pre class="code">r.Mutex.RLock()
now := time.Now()
bucket, exists := r.Buckets[now.Unix()]
r.Mutex.RUnlock()

if !exists {
	r.Mutex.Lock()
	defer r.Mutex.Unlock()

	r.Buckets[now.Unix()] = &amp;timingBucket{}
	bucket = r.Buckets[now.Unix()]
}
</pre><p><strong>Unaffected</strong> (but uses wall representation multiple times).</p><h2><a class="h" name="Fixed" href="#Fixed"><span></span></a><a class="h" name="fixed" href="#fixed"><span></span></a>Fixed</h2><h3><a class="h" name="github_com_hashicorp_vault_vendor_golang_org_x_net_http2_transport_go_721" href="#github_com_hashicorp_vault_vendor_golang_org_x_net_http2_transport_go_721"><span></span></a>github.com/hashicorp/vault/vendor/golang.org/x/net/http2/transport.go:721</h3><pre class="code">func (cc *ClientConn) RoundTrip(req *http.Request) (*http.Response, error) {
	...
	cc.lastActive = time.Now()
	...
}
</pre><p>matches against:</p><pre class="code">func traceGotConn(req *http.Request, cc *ClientConn) {
	... ci.IdleTime = time.Now().Sub(cc.lastActive) ...
}
</pre><p><strong>Fixed.</strong> Only for debugging, though.</p><h3><a class="h" name="github_com_docker_docker_vendor_github_com_hashicorp_serf_serf_serf_go_1417" href="#github_com_docker_docker_vendor_github_com_hashicorp_serf_serf_serf_go_1417"><span></span></a>github.com/docker/docker/vendor/github.com/hashicorp/serf/serf/serf.go:1417</h3><pre class="code">// reap is called with a list of old members and a timeout, and removes
// members that have exceeded the timeout. The members are removed from
// both the old list and the members itself. Locking is left to the caller.
func (s *Serf) reap(old []*memberState, timeout time.Duration) []*memberState {
	now := time.Now()
	...
	for i := 0; i &lt; n; i++ {
		...
		// Skip if the timeout is not yet reached
		if now.Sub(m.leaveTime) &lt;= timeout {
			continue
		}
		...
	}
	...
}
</pre><p>and m.leaveTime is always initialized by calling time.Now.</p><p><strong>Fixed.</strong></p><h3><a class="h" name="github_com_hashicorp_consul_consul_acl_replication_go_173" href="#github_com_hashicorp_consul_consul_acl_replication_go_173"><span></span></a>github.com/hashicorp/consul/consul/acl_replication.go:173</h3><pre class="code">defer metrics.MeasureSince([]string{&quot;consul&quot;, &quot;leader&quot;, &quot;updateLocalACLs&quot;}, time.Now())
</pre><p>This is the canonical way to use the github.com/armon/go-metrics package.</p><pre class="code">func MeasureSince(key []string, start time.Time) {
	globalMetrics.MeasureSince(key, start)
}

func (m *Metrics) MeasureSince(key []string, start time.Time) {
	...
	now := time.Now()
	elapsed := now.Sub(start)
	msec := float32(elapsed.Nanoseconds()) / float32(m.TimerGranularity)
	m.sink.AddSample(key, msec)
}
</pre><p><strong>Fixed.</strong></p><h3><a class="h" name="github_com_flynn_flynn_vendor_gopkg_in_mgo_v2_session_go_3598" href="#github_com_flynn_flynn_vendor_gopkg_in_mgo_v2_session_go_3598"><span></span></a>github.com/flynn/flynn/vendor/gopkg.in/mgo.v2/session.go:3598</h3><pre class="code">if iter.timeout &gt;= 0 {
	if timeout.IsZero() {
		timeout = time.Now().Add(iter.timeout)
	}
	if time.Now().After(timeout) {
		iter.timedout = true
		...
	}
}
</pre><p><strong>Fixed.</strong></p><h3><a class="h" name="github_com_huichen_wukong_examples_benchmark_go_173" href="#github_com_huichen_wukong_examples_benchmark_go_173"><span></span></a>github.com/huichen/wukong/examples/benchmark.go:173</h3><pre class="code">t4 := time.Now()
done := make(chan bool)
recordResponse := recordResponseLock{}
recordResponse.count = make(map[string]int)
for iThread := 0; iThread &lt; numQueryThreads; iThread++ {
	go search(done, &amp;recordResponse)
}
for iThread := 0; iThread &lt; numQueryThreads; iThread++ {
	&lt;-done
}

// 记录时间并计算分词速度
t5 := time.Now()
log.Printf(&quot;搜索平均响应时间 %v 毫秒&quot;,
	t5.Sub(t4).Seconds()*1000/float64(numRepeatQuery*len(searchQueries)))
log.Printf(&quot;搜索吞吐量每秒 %v 次查询&quot;,
	float64(numRepeatQuery*numQueryThreads*len(searchQueries))/
		t5.Sub(t4).Seconds())
</pre><p>The first print is &ldquo;Search average response time %v milliseconds&rdquo; and the second is &ldquo;Search Throughput %v queries per second.&rdquo;</p><p><strong>Fixed.</strong></p><h3><a class="h" name="github_com_ncw_rclone_vendor_google_golang_org_grpc_call_go_171" href="#github_com_ncw_rclone_vendor_google_golang_org_grpc_call_go_171"><span></span></a>github.com/ncw/rclone/vendor/google.golang.org/grpc/call.go:171</h3><pre class="code">if EnableTracing {
	...
	if deadline, ok := ctx.Deadline(); ok {
		c.traceInfo.firstLine.deadline = deadline.Sub(time.Now())
	}
	...
}
</pre><p>Here ctx is a context.Context. We should probably arrange for ctx.Deadline to return monotonic times. If it does, then this code is fixed. If it does not, then this code is unaffected.</p><p><strong>Fixed.</strong></p><h3><a class="h" name="github_com_hashicorp_consul_consul_fsm_go_281" href="#github_com_hashicorp_consul_consul_fsm_go_281"><span></span></a>github.com/hashicorp/consul/consul/fsm.go:281</h3><pre class="code">defer metrics.MeasureSince([]string{&quot;consul&quot;, &quot;fsm&quot;, &quot;prepared-query&quot;, string(req.Op)}, time.Now())
</pre><p>See MeasureSince above.</p><p><strong>Fixed.</strong></p><h3><a class="h" name="github_com_docker_libnetwork_vendor_github_com_Sirupsen_logrus_text_formatter_go_27" href="#github_com_docker_libnetwork_vendor_github_com_Sirupsen_logrus_text_formatter_go_27"><span></span></a><a class="h" name="github_com_docker_libnetwork_vendor_github_com_sirupsen_logrus_text_formatter_go_27" href="#github_com_docker_libnetwork_vendor_github_com_sirupsen_logrus_text_formatter_go_27"><span></span></a>github.com/docker/libnetwork/vendor/github.com/Sirupsen/logrus/text_formatter.go:27</h3><pre class="code">var (
	baseTimestamp time.Time
	isTerminal    bool
)

func init() {
	baseTimestamp = time.Now()
	isTerminal = IsTerminal()
}

func miniTS() int {
	return int(time.Since(baseTimestamp) / time.Second)
}
</pre><p><strong>Fixed.</strong></p><h3><a class="h" name="github_com_flynn_flynn_vendor_golang_org_x_net_http2_go17_go_54" href="#github_com_flynn_flynn_vendor_golang_org_x_net_http2_go17_go_54"><span></span></a>github.com/flynn/flynn/vendor/golang.org/x/net/http2/go17.go:54</h3><pre class="code">if ci.WasIdle &amp;&amp; !cc.lastActive.IsZero() {
	ci.IdleTime = time.Now().Sub(cc.lastActive)
}
</pre><p>See above.</p><p><strong>Fixed.</strong></p><h3><a class="h" name="github_com_zyedidia_micro_cmd_micro_eventhandler_go_102" href="#github_com_zyedidia_micro_cmd_micro_eventhandler_go_102"><span></span></a>github.com/zyedidia/micro/cmd/micro/eventhandler.go:102</h3><pre class="code">// Remove creates a remove text event and executes it
func (eh *EventHandler) Remove(start, end Loc) {
	e := &amp;TextEvent{
		C:         eh.buf.Cursor,
		EventType: TextEventRemove,
		Start:     start,
		End:       end,
		Time:      time.Now(),
	}
	eh.Execute(e)
}
</pre><p>The time here is used by</p><pre class="code">// Undo the first event in the undo stack
func (eh *EventHandler) Undo() {
	t := eh.UndoStack.Peek()
	...
	startTime := t.Time.UnixNano() / int64(time.Millisecond)
	...
	for {
		t = eh.UndoStack.Peek()
		...
		if startTime-(t.Time.UnixNano()/int64(time.Millisecond)) &gt; undoThreshold {
			return
		}
		startTime = t.Time.UnixNano() / int64(time.Millisecond)
		...
	}
}
</pre><p>If this avoided the call to UnixNano (used t.Sub instead), then all the times involved would be monotonic and the elapsed time computation would be independent of wall time. As written, a wall time adjustment during Undo will still break the code. Without any monotonic times, a wall time adjustment before Undo also breaks the code; that no longer happens.</p><p>*<em>Fixed.</em></p><h3><a class="h" name="github_com_ethereum_go_ethereum_cmd_geth_chaincmd_go_186" href="#github_com_ethereum_go_ethereum_cmd_geth_chaincmd_go_186"><span></span></a>github.com/ethereum/go-ethereum/cmd/geth/chaincmd.go:186</h3><pre class="code">start = time.Now()
fmt.Println(&quot;Compacting entire database...&quot;)
if err = db.LDB().CompactRange(util.Range{}); err != nil {
	utils.Fatalf(&quot;Compaction failed: %v&quot;, err)
}
fmt.Printf(&quot;Compaction done in %v.\n\n&quot;, time.Since(start))
</pre><p><strong>Fixed.</strong></p><h3><a class="h" name="github_com_drone_drone_shared_oauth2_oauth2_go_176" href="#github_com_drone_drone_shared_oauth2_oauth2_go_176"><span></span></a>github.com/drone/drone/shared/oauth2/oauth2.go:176</h3><pre class="code">// Expired reports whether the token has expired or is invalid.
func (t *Token) Expired() bool {
	if t.AccessToken == &quot;&quot; {
		return true
	}
	if t.Expiry.IsZero() {
		return false
	}
	return t.Expiry.Before(time.Now())
}
</pre><p>t.Expiry is set with:</p><pre class="code">if b.ExpiresIn == 0 {
	tok.Expiry = time.Time{}
} else {
	tok.Expiry = time.Now().Add(time.Duration(b.ExpiresIn) * time.Second)
}
</pre><p><strong>Fixed.</strong></p><h3><a class="h" name="github_com_coreos_etcd_auth_simple_token_go_88" href="#github_com_coreos_etcd_auth_simple_token_go_88"><span></span></a>github.com/coreos/etcd/auth/simple_token.go:88</h3><pre class="code">for {
	select {
	case t := &lt;-tm.addSimpleTokenCh:
		tm.tokens[t] = time.Now().Add(simpleTokenTTL)
	case t := &lt;-tm.resetSimpleTokenCh:
		if _, ok := tm.tokens[t]; ok {
			tm.tokens[t] = time.Now().Add(simpleTokenTTL)
		}
	case t := &lt;-tm.deleteSimpleTokenCh:
		delete(tm.tokens, t)
	case &lt;-tokenTicker.C:
		nowtime := time.Now()
		for t, tokenendtime := range tm.tokens {
			if nowtime.After(tokenendtime) {
				tm.deleteTokenFunc(t)
				delete(tm.tokens, t)
			}
		}
	case waitCh := &lt;-tm.stopCh:
		tm.tokens = make(map[string]time.Time)
		waitCh &lt;- struct{}{}
		return
	}
}
</pre><p><strong>Fixed.</strong></p><h3><a class="h" name="github_com_docker_docker_cli_command_node_ps_test_go_105" href="#github_com_docker_docker_cli_command_node_ps_test_go_105"><span></span></a>github.com/docker/docker/cli/command/node/ps_test.go:105</h3><pre class="code">return []swarm.Task{
	*Task(TaskID(&quot;taskID1&quot;), ServiceID(&quot;failure&quot;),
		WithStatus(Timestamp(time.Now().Add(-2*time.Hour)), StatusErr(&quot;a task error&quot;))),
	*Task(TaskID(&quot;taskID2&quot;), ServiceID(&quot;failure&quot;),
		WithStatus(Timestamp(time.Now().Add(-3*time.Hour)), StatusErr(&quot;a task error&quot;))),
	*Task(TaskID(&quot;taskID3&quot;), ServiceID(&quot;failure&quot;),
		WithStatus(Timestamp(time.Now().Add(-4*time.Hour)), StatusErr(&quot;a task error&quot;))),
}, nil
</pre><p>It&#39;s just a test, but Timestamp sets the Timestamp field in the swarm.TaskStatus used eventually in docker/cli/command/task/print.go:</p><pre class="code">strings.ToLower(units.HumanDuration(time.Since(task.Status.Timestamp))),
</pre><p>Having a monotonic time in the swam.TaskStatus makes time.Since more accurate.</p><p><strong>Fixed.</strong></p><h3><a class="h" name="github_com_docker_docker_integration_cli_docker_api_attach_test_go_130" href="#github_com_docker_docker_integration_cli_docker_api_attach_test_go_130"><span></span></a>github.com/docker/docker/integration-cli/docker_api_attach_test.go:130</h3><pre class="code">conn.SetReadDeadline(time.Now().Add(time.Second))
</pre><p><strong>Fixed.</strong></p><h3><a class="h" name="github_com_openshift_origin_vendor_k8s_io_kubernetes_test_e2e_framework_util_go_1696" href="#github_com_openshift_origin_vendor_k8s_io_kubernetes_test_e2e_framework_util_go_1696"><span></span></a>github.com/openshift/origin/vendor/k8s.io/kubernetes/test/e2e/framework/util.go:1696</h3><pre class="code">timeout := 2 * time.Minute
for start := time.Now(); time.Since(start) &lt; timeout; time.Sleep(5 * time.Second) {
	...
}
</pre><p><strong>Fixed.</strong></p><h3><a class="h" name="github_com_onsi_gomega_internal_asyncassertion_async_assertion_test_go_318" href="#github_com_onsi_gomega_internal_asyncassertion_async_assertion_test_go_318"><span></span></a>github.com/onsi/gomega/internal/asyncassertion/async_assertion_test.go:318</h3><pre class="code">t := time.Now()
failures := InterceptGomegaFailures(func() {
	Eventually(c, 0.1).Should(Receive())
})
Ω(time.Since(t)).Should(BeNumerically(&quot;&lt;&quot;, 90*time.Millisecond))
</pre><p><strong>Fixed.</strong></p><h3><a class="h" name="github_com_hashicorp_vault_physical_consul_go_344" href="#github_com_hashicorp_vault_physical_consul_go_344"><span></span></a>github.com/hashicorp/vault/physical/consul.go:344</h3><pre class="code">defer metrics.MeasureSince([]string{&quot;consul&quot;, &quot;list&quot;}, time.Now())
</pre><p><strong>Fixed.</strong></p><h3><a class="h" name="github_com_hyperledger_fabric_vendor_golang_org_x_net_context_go17_go_62" href="#github_com_hyperledger_fabric_vendor_golang_org_x_net_context_go17_go_62"><span></span></a>github.com/hyperledger/fabric/vendor/golang.org/x/net/context/go17.go:62</h3><pre class="code">// WithTimeout returns WithDeadline(parent, time.Now().Add(timeout)).
// ...
func WithTimeout(parent Context, timeout time.Duration) (Context, CancelFunc) {
	return WithDeadline(parent, time.Now().Add(timeout))
}
</pre><p><strong>Fixed.</strong></p><h3><a class="h" name="github_com_hashicorp_consul_consul_state_tombstone_gc_go_134" href="#github_com_hashicorp_consul_consul_state_tombstone_gc_go_134"><span></span></a>github.com/hashicorp/consul/consul/state/tombstone_gc.go:134</h3><pre class="code">// nextExpires is used to calculate the next expiration time
func (t *TombstoneGC) nextExpires() time.Time {
	expires := time.Now().Add(t.ttl)
	remain := expires.UnixNano() % int64(t.granularity)
	adj := expires.Add(t.granularity - time.Duration(remain))
	return adj
}
</pre><p>used by:</p><pre class="code">func (t *TombstoneGC) Hint(index uint64) {
	expires := t.nextExpires()
	...
	// Check for an existing expiration timer
	exp, ok := t.expires[expires]
	if ok {
		...
		return
	}

	// Create new expiration time
	t.expires[expires] = &amp;expireInterval{
		maxIndex: index,
		timer: time.AfterFunc(expires.Sub(time.Now()), func() {
			t.expireTime(expires)
		}),
	}
}
</pre><p>The granularity rounding will usually reuslt in something that can be used in a map key but not always. The code is using the rounding only as an optimization, so it doesn&#39;t actually matter if a few extra keys get generated. More importantly, the time passd to time.AfterFunc ends up monotonic, so that timers fire correctly.</p><p><strong>Fixed.</strong></p><h3><a class="h" name="github_com_openshift_origin_vendor_k8s_io_kubernetes_pkg_storage_etcd_etcd_helper_go_310" href="#github_com_openshift_origin_vendor_k8s_io_kubernetes_pkg_storage_etcd_etcd_helper_go_310"><span></span></a>github.com/openshift/origin/vendor/k8s.io/kubernetes/pkg/storage/etcd/etcd_helper.go:310</h3><pre class="code">startTime := time.Now()
...
metrics.RecordEtcdRequestLatency(&quot;get&quot;, getTypeName(listPtr), startTime)
</pre><p>which ends up in:</p><pre class="code">func RecordEtcdRequestLatency(verb, resource string, startTime time.Time) {
	etcdRequestLatenciesSummary.WithLabelValues(verb, resource).Observe(float64(time.Since(startTime) / time.Microsecond))
}
</pre><p><strong>Fixed.</strong></p><h3><a class="h" name="github_com_pingcap_pd_server_util_go_215" href="#github_com_pingcap_pd_server_util_go_215"><span></span></a>github.com/pingcap/pd/server/util.go:215</h3><pre class="code">start := time.Now()
ctx, cancel := context.WithTimeout(c.Ctx(), requestTimeout)
resp, err := m.Status(ctx, endpoint)
cancel()

if cost := time.Now().Sub(start); cost &gt; slowRequestTime {
	log.Warnf(&quot;check etcd %s status, resp: %v, err: %v, cost: %s&quot;, endpoint, resp, err, cost)
}
</pre><p><strong>Fixed.</strong></p><h3><a class="h" name="github_com_openshift_origin_vendor_k8s_io_kubernetes_pkg_kubelet_kuberuntime_instrumented_services_go_235" href="#github_com_openshift_origin_vendor_k8s_io_kubernetes_pkg_kubelet_kuberuntime_instrumented_services_go_235"><span></span></a>github.com/openshift/origin/vendor/k8s.io/kubernetes/pkg/kubelet/kuberuntime/instrumented_services.go:235</h3><pre class="code">func (in instrumentedImageManagerService) ImageStatus(image *runtimeApi.ImageSpec) (*runtimeApi.Image, error) {
	...
	defer recordOperation(operation, time.Now())
	...
}

// recordOperation records the duration of the operation.
func recordOperation(operation string, start time.Time) {
	metrics.RuntimeOperations.WithLabelValues(operation).Inc()
	metrics.RuntimeOperationsLatency.WithLabelValues(operation).Observe(metrics.SinceInMicroseconds(start))
}
</pre><p><strong>Fixed.</strong></p><h3><a class="h" name="github_com_openshift_origin_vendor_k8s_io_kubernetes_pkg_kubelet_dockertools_instrumented_docker_go_58" href="#github_com_openshift_origin_vendor_k8s_io_kubernetes_pkg_kubelet_dockertools_instrumented_docker_go_58"><span></span></a>github.com/openshift/origin/vendor/k8s.io/kubernetes/pkg/kubelet/dockertools/instrumented_docker.go:58</h3><pre class="code">defer recordOperation(operation, time.Now())
</pre><p><strong>Fixed.</strong> (see previous)</p><h3><a class="h" name="github_com_coreos_etcd_tools_functional_tester_etcd_runner_command_global_go_103" href="#github_com_coreos_etcd_tools_functional_tester_etcd_runner_command_global_go_103"><span></span></a>github.com/coreos/etcd/tools/functional-tester/etcd-runner/command/global.go:103</h3><pre class="code">start := time.Now()
for i := 1; i &lt; len(rcs)*rounds+1; i++ {
	select {
	case &lt;-finished:
		if i%100 == 0 {
			fmt.Printf(&quot;finished %d, took %v\n&quot;, i, time.Since(start))
			start = time.Now()
		}
	case &lt;-time.After(time.Minute):
		log.Panic(&quot;no progress after 1 minute!&quot;)
	}
}
</pre><p><strong>Fixed.</strong></p><h3><a class="h" name="github_com_reducedb_encoding_benchtools_benchtools_go_98" href="#github_com_reducedb_encoding_benchtools_benchtools_go_98"><span></span></a>github.com/reducedb/encoding/benchtools/benchtools.go:98</h3><pre class="code">now := time.Now()
...
if err = codec.Compress(in, inpos, len(in), out, outpos); err != nil {
	return 0, nil, err
}
since := time.Since(now).Nanoseconds()
</pre><p><strong>Fixed.</strong></p><h3><a class="h" name="github_com_docker_swarm_vendor_github_com_hashicorp_consul_api_semaphore_go_200" href="#github_com_docker_swarm_vendor_github_com_hashicorp_consul_api_semaphore_go_200"><span></span></a>github.com/docker/swarm/vendor/github.com/hashicorp/consul/api/semaphore.go:200</h3><pre class="code">	start := time.Now()
	attempts := 0
WAIT:
	// Check if we should quit
	select {
	case &lt;-stopCh:
		return nil, nil
	default:
	}

	// Handle the one-shot mode.
	if s.opts.SemaphoreTryOnce &amp;&amp; attempts &gt; 0 {
		elapsed := time.Now().Sub(start)
		if elapsed &gt; qOpts.WaitTime {
			return nil, nil
		}

		qOpts.WaitTime -= elapsed
	}
	attempts++
	... goto WAIT ...
</pre><p><strong>Fixed.</strong></p><h3><a class="h" name="github_com_gravitational_teleport_lib_reversetunnel_localsite_go_83" href="#github_com_gravitational_teleport_lib_reversetunnel_localsite_go_83"><span></span></a>github.com/gravitational/teleport/lib/reversetunnel/localsite.go:83</h3><pre class="code">func (s *localSite) GetLastConnected() time.Time {
	return time.Now()
}
</pre><p>This gets recorded in a services.Site&#39;s LastConnected field, the only use of which is:</p><pre class="code">c.Assert(time.Since(sites[0].LastConnected).Seconds() &lt; 5, Equals, true)
</pre><p><strong>Fixed.</strong></p><h3><a class="h" name="github_com_coreos_etcd_tools_benchmark_cmd_watch_go_201" href="#github_com_coreos_etcd_tools_benchmark_cmd_watch_go_201"><span></span></a>github.com/coreos/etcd/tools/benchmark/cmd/watch.go:201</h3><pre class="code">st := time.Now()
for range r.Events {
	results &lt;- report.Result{Start: st, End: time.Now()}
	bar.Increment()
	atomic.AddInt32(&amp;nrRecvCompleted, 1)
}
</pre><p>Those fields get used by</p><pre class="code">func (res *Result) Duration() time.Duration { return res.End.Sub(res.Start) }

func (r *report) processResult(res *Result) {
	if res.Err != nil {
		r.errorDist[res.Err.Error()]++
		return
	}
	dur := res.Duration()
	r.lats = append(r.lats, dur.Seconds())
	r.avgTotal += dur.Seconds()
	if r.sps != nil {
		r.sps.Add(res.Start, dur)
	}
}
</pre><p>The duration computation is fixed by use of monotonic time. The call tp r.sps.Add buckets the start time by converting to Unix seconds and is therefore unaffected (start time only used once other than the duration calculation, so no visible jitter).</p><p><strong>Fixed.</strong></p><h3><a class="h" name="github_com_flynn_flynn_vendor_github_com_flynn_oauth2_internal_token_go_191" href="#github_com_flynn_flynn_vendor_github_com_flynn_oauth2_internal_token_go_191"><span></span></a>github.com/flynn/flynn/vendor/github.com/flynn/oauth2/internal/token.go:191</h3><pre class="code">token.Expiry = time.Now().Add(time.Duration(expires) * time.Second)
</pre><p>used by:</p><pre class="code">func (t *Token) expired() bool {
	if t.Expiry.IsZero() {
		return false
	}
	return t.Expiry.Add(-expiryDelta).Before(time.Now())
}
</pre><p>Only partly fixed because sometimes token.Expiry has been loaded from a JSON serialization of a fixed time. But in the case where the expiry was set from a duration, the duration is now correctly enforced.</p><p><strong>Fixed.</strong></p><h3><a class="h" name="github_com_hashicorp_consul_consul_fsm_go_266" href="#github_com_hashicorp_consul_consul_fsm_go_266"><span></span></a>github.com/hashicorp/consul/consul/fsm.go:266</h3><pre class="code">defer metrics.MeasureSince([]string{&quot;consul&quot;, &quot;fsm&quot;, &quot;coordinate&quot;, &quot;batch-update&quot;}, time.Now())
</pre><p><strong>Fixed.</strong></p><h3><a class="h" name="github_com_openshift_origin_vendor_github_com_coreos_etcd_clientv3_lease_go_437" href="#github_com_openshift_origin_vendor_github_com_coreos_etcd_clientv3_lease_go_437"><span></span></a>github.com/openshift/origin/vendor/github.com/coreos/etcd/clientv3/lease.go:437</h3><pre class="code">now := time.Now()
l.mu.Lock()
for id, ka := range l.keepAlives {
	if ka.nextKeepAlive.Before(now) {
		tosend = append(tosend, id)
	}
}
l.mu.Unlock()
</pre><p>ka.nextKeepAlive is set to either time.Now() or</p><pre class="code">nextKeepAlive := time.Now().Add(1 + time.Duration(karesp.TTL/3)*time.Second)
</pre><p><strong>Fixed.</strong></p><h3><a class="h" name="github_com_eBay_fabio_cert_source_test_go_567" href="#github_com_eBay_fabio_cert_source_test_go_567"><span></span></a><a class="h" name="github_com_ebay_fabio_cert_source_test_go_567" href="#github_com_ebay_fabio_cert_source_test_go_567"><span></span></a>github.com/eBay/fabio/cert/source_test.go:567</h3><pre class="code">func waitFor(timeout time.Duration, up func() bool) bool {
	until := time.Now().Add(timeout)
	for {
		if time.Now().After(until) {
			return false
		}
		if up() {
			return true
		}
		time.Sleep(100 * time.Millisecond)
	}
}
</pre><p><strong>Fixed.</strong></p><h3><a class="h" name="github_com_lucas_clemente_quic_go_ackhandler_sent_packet_handler_test_go_524" href="#github_com_lucas_clemente_quic_go_ackhandler_sent_packet_handler_test_go_524"><span></span></a>github.com/lucas-clemente/quic-go/ackhandler/sent_packet_handler_test.go:524</h3><pre class="code">err := handler.ReceivedAck(&amp;frames.AckFrame{LargestAcked: 1}, 1, time.Now())
Expect(err).NotTo(HaveOccurred())
Expect(handler.rttStats.LatestRTT()).To(BeNumerically(&quot;~&quot;, 10*time.Minute, 1*time.Second))
err = handler.ReceivedAck(&amp;frames.AckFrame{LargestAcked: 2}, 2, time.Now())
Expect(err).NotTo(HaveOccurred())
Expect(handler.rttStats.LatestRTT()).To(BeNumerically(&quot;~&quot;, 5*time.Minute, 1*time.Second))
err = handler.ReceivedAck(&amp;frames.AckFrame{LargestAcked: 6}, 3, time.Now())
Expect(err).NotTo(HaveOccurred())
Expect(handler.rttStats.LatestRTT()).To(BeNumerically(&quot;~&quot;, 1*time.Minute, 1*time.Second))
</pre><p>where:</p><pre class="code">func (h *sentPacketHandler) ReceivedAck(ackFrame *frames.AckFrame, withPacketNumber protocol.PacketNumber, rcvTime time.Time) error {
	...
	timeDelta := rcvTime.Sub(packet.SendTime)
	h.rttStats.UpdateRTT(timeDelta, ackFrame.DelayTime, rcvTime)
	...
}
</pre><p>and packet.SendTime is initialized (earlier) with time.Now.</p><p><strong>Fixed.</strong></p><h3><a class="h" name="github_com_CodisLabs_codis_pkg_proxy_redis_conn_go_140" href="#github_com_CodisLabs_codis_pkg_proxy_redis_conn_go_140"><span></span></a><a class="h" name="github_com_codislabs_codis_pkg_proxy_redis_conn_go_140" href="#github_com_codislabs_codis_pkg_proxy_redis_conn_go_140"><span></span></a>github.com/CodisLabs/codis/pkg/proxy/redis/conn.go:140</h3><pre class="code">func (w *connWriter) Write(b []byte) (int, error) {
	...
	w.LastWrite = time.Now()
	...
}
</pre><p>used by:</p><pre class="code">func (p *FlushEncoder) NeedFlush() bool {
	...
	if p.MaxInterval &lt; time.Since(p.Conn.LastWrite) {
		return true
	}
	...
}
</pre><p><strong>Fixed.</strong></p><h3><a class="h" name="github_com_docker_docker_vendor_github_com_docker_swarmkit_manager_scheduler_scheduler_go_173" href="#github_com_docker_docker_vendor_github_com_docker_swarmkit_manager_scheduler_scheduler_go_173"><span></span></a>github.com/docker/docker/vendor/github.com/docker/swarmkit/manager/scheduler/scheduler.go:173</h3><pre class="code">func (s *Scheduler) Run(ctx context.Context) error {
	...
	var (
		debouncingStarted     time.Time
		commitDebounceTimer   *time.Timer
	)
	...

	// Watch for changes.
	for {
		select {
		case event := &lt;-updates:
			switch v := event.(type) {
			case state.EventCommit:
				if commitDebounceTimer != nil {
					if time.Since(debouncingStarted) &gt; maxLatency {
						...
					}
				} else {
					commitDebounceTimer = time.NewTimer(commitDebounceGap)
					debouncingStarted = time.Now()
					...
				}
			}
		...
	}
}
</pre><p><strong>Fixed.</strong></p><h3><a class="h" name="golang_org_x_net_nettest_conntest_go_361" href="#golang_org_x_net_nettest_conntest_go_361"><span></span></a>golang.org/x/net/nettest/conntest.go:361</h3><pre class="code">c1.SetDeadline(time.Now().Add(10 * time.Millisecond))
</pre><p><strong>Fixed.</strong></p><h3><a class="h" name="github_com_minio_minio_vendor_github_com_eapache_go_resiliency_breaker_breaker_go_120" href="#github_com_minio_minio_vendor_github_com_eapache_go_resiliency_breaker_breaker_go_120"><span></span></a>github.com/minio/minio/vendor/github.com/eapache/go-resiliency/breaker/breaker.go:120</h3><pre class="code">expiry := b.lastError.Add(b.timeout)
if time.Now().After(expiry) {
	b.errors = 0
}
</pre><p>where b.lastError is set using time.Now.</p><p><strong>Fixed.</strong></p><h3><a class="h" name="github_com_pingcap_tidb_store_tikv_client_go_65" href="#github_com_pingcap_tidb_store_tikv_client_go_65"><span></span></a>github.com/pingcap/tidb/store/tikv/client.go:65</h3><pre class="code">start := time.Now()
defer func() { sendReqHistogram.WithLabelValues(&quot;cop&quot;).Observe(time.Since(start).Seconds()) }()
</pre><p><strong>Fixed.</strong></p><h3><a class="h" name="github_com_coreos_etcd_cmd_vendor_golang_org_x_net_context_go17_go_62" href="#github_com_coreos_etcd_cmd_vendor_golang_org_x_net_context_go17_go_62"><span></span></a>github.com/coreos/etcd/cmd/vendor/golang.org/x/net/context/go17.go:62</h3><pre class="code">return WithDeadline(parent, time.Now().Add(timeout))
</pre><p><strong>Fixed</strong> (see above).</p><h3><a class="h" name="github_com_coreos_rkt_rkt_image_common_test_go_161" href="#github_com_coreos_rkt_rkt_image_common_test_go_161"><span></span></a>github.com/coreos/rkt/rkt/image/common_test.go:161</h3><pre class="code">maxAge := 10
for _, tt := range tests {
	age := time.Now().Add(time.Duration(tt.age) * time.Second)
	got := useCached(age, maxAge)
	if got != tt.use {
		t.Errorf(&quot;expected useCached(%v, %v) to return %v, but it returned %v&quot;, age, maxAge, tt.use, got)
	}
}
</pre><p>where:</p><pre class="code">func useCached(downloadTime time.Time, maxAge int) bool {
	freshnessLifetime := int(time.Now().Sub(downloadTime).Seconds())
	if maxAge &gt; 0 &amp;&amp; freshnessLifetime &lt; maxAge {
		return true
	}
	return false
}
</pre><p><strong>Fixed.</strong></p><h3><a class="h" name="github_com_lucas_clemente_quic_go_flowcontrol_flow_controller_go_131" href="#github_com_lucas_clemente_quic_go_flowcontrol_flow_controller_go_131"><span></span></a>github.com/lucas-clemente/quic-go/flowcontrol/flow_controller.go:131</h3><pre class="code">c.lastWindowUpdateTime = time.Now()
</pre><p>used as:</p><pre class="code">if c.lastWindowUpdateTime.IsZero() {
	return
}
...
timeSinceLastWindowUpdate := time.Now().Sub(c.lastWindowUpdateTime)
</pre><p><strong>Fixed.</strong></p><h3><a class="h" name="github_com_hashicorp_serf_serf_snapshot_go_327" href="#github_com_hashicorp_serf_serf_snapshot_go_327"><span></span></a>github.com/hashicorp/serf/serf/snapshot.go:327</h3><pre class="code">now := time.Now()
if now.Sub(s.lastFlush) &gt; flushInterval {
	s.lastFlush = now
	if err := s.buffered.Flush(); err != nil {
		return err
	}
}
</pre><p><strong>Fixed.</strong></p><h3><a class="h" name="github_com_junegunn_fzf_src_matcher_go_210" href="#github_com_junegunn_fzf_src_matcher_go_210"><span></span></a>github.com/junegunn/fzf/src/matcher.go:210</h3><pre class="code">startedAt := time.Now()
...
for matchesInChunk := range countChan {
	...
	if time.Now().Sub(startedAt) &gt; progressMinDuration {
		m.eventBox.Set(EvtSearchProgress, float32(count)/float32(numChunks))
	}
}
</pre><p><strong>Fixed.</strong></p><h3><a class="h" name="github_com_mitchellh_packer_vendor_google_golang_org_appengine_demos_helloworld_helloworld_go_19" href="#github_com_mitchellh_packer_vendor_google_golang_org_appengine_demos_helloworld_helloworld_go_19"><span></span></a>github.com/mitchellh/packer/vendor/google.golang.org/appengine/demos/helloworld/helloworld.go:19</h3><pre class="code">var initTime = time.Now()

func handle(w http.ResponseWriter, r *http.Request) {
	...
	tmpl.Execute(w, time.Since(initTime))
}
</pre><p><strong>Fixed.</strong></p><h3><a class="h" name="github_com_ncw_rclone_vendor_google_golang_org_appengine_internal_api_go_549" href="#github_com_ncw_rclone_vendor_google_golang_org_appengine_internal_api_go_549"><span></span></a>github.com/ncw/rclone/vendor/google.golang.org/appengine/internal/api.go:549</h3><pre class="code">func (c *context) logFlusher(stop &lt;-chan int) {
	lastFlush := time.Now()
	tick := time.NewTicker(flushInterval)
	for {
		select {
		case &lt;-stop:
			// Request finished.
			tick.Stop()
			return
		case &lt;-tick.C:
			force := time.Now().Sub(lastFlush) &gt; forceFlushInterval
			if c.flushLog(force) {
				lastFlush = time.Now()
			}
		}
	}
}
</pre><p><strong>Fixed.</strong></p><h3><a class="h" name="github_com_ethereum_go_ethereum_cmd_geth_chaincmd_go_159" href="#github_com_ethereum_go_ethereum_cmd_geth_chaincmd_go_159"><span></span></a>github.com/ethereum/go-ethereum/cmd/geth/chaincmd.go:159</h3><pre class="code">start := time.Now()
...
fmt.Printf(&quot;Import done in %v.\n\n&quot;, time.Since(start))
</pre><p><strong>Fixed.</strong></p><h3><a class="h" name="github_com_nats_io_nats_test_conn_test_go_652" href="#github_com_nats_io_nats_test_conn_test_go_652"><span></span></a>github.com/nats-io/nats/test/conn_test.go:652</h3><pre class="code">if firstDisconnect {
	firstDisconnect = false
	dtime1 = time.Now()
} else {
	dtime2 = time.Now()
}
</pre><p>and later:</p><pre class="code">if (dtime1 == time.Time{}) || (dtime2 == time.Time{}) || (rtime == time.Time{}) || (atime1 == time.Time{}) || (atime2 == time.Time{}) || (ctime == time.Time{}) {
	t.Fatalf(&quot;Some callbacks did not fire:\n%v\n%v\n%v\n%v\n%v\n%v&quot;, dtime1, rtime, atime1, atime2, dtime2, ctime)
}

if rtime.Before(dtime1) || dtime2.Before(rtime) || atime2.Before(atime1) || ctime.Before(atime2) {
	t.Fatalf(&quot;Wrong callback order:\n%v\n%v\n%v\n%v\n%v\n%v&quot;, dtime1, rtime, atime1, atime2, dtime2, ctime)
}
</pre><p><strong>Fixed.</strong></p><h3><a class="h" name="github_com_google_cadvisor_manager_container_go_456" href="#github_com_google_cadvisor_manager_container_go_456"><span></span></a>github.com/google/cadvisor/manager/container.go:456</h3><pre class="code">// Schedule the next housekeeping. Sleep until that time.
if time.Now().Before(next) {
	time.Sleep(next.Sub(time.Now()))
} else {
	next = time.Now()
}
lastHousekeeping = next
</pre><p><strong>Fixed.</strong></p><h3><a class="h" name="github_com_google_cadvisor_vendor_golang_org_x_oauth2_token_go_98" href="#github_com_google_cadvisor_vendor_golang_org_x_oauth2_token_go_98"><span></span></a>github.com/google/cadvisor/vendor/golang.org/x/oauth2/token.go:98</h3><pre class="code">return t.Expiry.Add(-expiryDelta).Before(time.Now())
</pre><p><strong>Fixed</strong> (see above).</p><h3><a class="h" name="github_com_hashicorp_consul_consul_fsm_go_109" href="#github_com_hashicorp_consul_consul_fsm_go_109"><span></span></a>github.com/hashicorp/consul/consul/fsm.go:109</h3><pre class="code">defer metrics.MeasureSince([]string{&quot;consul&quot;, &quot;fsm&quot;, &quot;register&quot;}, time.Now())
</pre><p><strong>Fixed.</strong></p><h3><a class="h" name="github_com_hashicorp_vault_vendor_github_com_hashicorp_yamux_session_go_295" href="#github_com_hashicorp_vault_vendor_github_com_hashicorp_yamux_session_go_295"><span></span></a>github.com/hashicorp/vault/vendor/github.com/hashicorp/yamux/session.go:295</h3><pre class="code">// Wait for a response
start := time.Now()
...

// Compute the RTT
return time.Now().Sub(start), nil
</pre><p><strong>Fixed.</strong></p><h3><a class="h" name="github_com_go_kit_kit_examples_shipping_booking_instrumenting_go_31" href="#github_com_go_kit_kit_examples_shipping_booking_instrumenting_go_31"><span></span></a>github.com/go-kit/kit/examples/shipping/booking/instrumenting.go:31</h3><pre class="code">defer func(begin time.Time) {
	s.requestCount.With(&quot;method&quot;, &quot;book&quot;).Add(1)
	s.requestLatency.With(&quot;method&quot;, &quot;book&quot;).Observe(time.Since(begin).Seconds())
}(time.Now())
</pre><p><strong>Fixed.</strong></p><h3><a class="h" name="github_com_cyfdecyf_cow_timeoutset_go_22" href="#github_com_cyfdecyf_cow_timeoutset_go_22"><span></span></a>github.com/cyfdecyf/cow/timeoutset.go:22</h3><pre class="code">func (ts *TimeoutSet) add(key string) {
	now := time.Now()
	ts.Lock()
	ts.time[key] = now
	ts.Unlock()
}
</pre><p>used by</p><pre class="code">func (ts *TimeoutSet) has(key string) bool {
	ts.RLock()
	t, ok := ts.time[key]
	ts.RUnlock()
	if !ok {
		return false
	}
	if time.Now().Sub(t) &gt; ts.timeout {
		ts.del(key)
		return false
	}
	return true
}
</pre><p><strong>Fixed.</strong></p><h3><a class="h" name="github_com_prometheus_prometheus_vendor_k8s_io_client_go_1_5_rest_request_go_761" href="#github_com_prometheus_prometheus_vendor_k8s_io_client_go_1_5_rest_request_go_761"><span></span></a>github.com/prometheus/prometheus/vendor/k8s.io/client-go/1.5/rest/request.go:761</h3><pre class="code">//Metrics for total request latency
start := time.Now()
defer func() {
	metrics.RequestLatency.Observe(r.verb, r.finalURLTemplate(), time.Since(start))
}()
</pre><p><strong>Fixed.</strong></p><h3><a class="h" name="github_com_ethereum_go_ethereum_p2p_discover_udp_go_383" href="#github_com_ethereum_go_ethereum_p2p_discover_udp_go_383"><span></span></a>github.com/ethereum/go-ethereum/p2p/discover/udp.go:383</h3><pre class="code">for {
	...
	select {
	...
	case p := &lt;-t.addpending:
		p.deadline = time.Now().Add(respTimeout)
		...

	case now := &lt;-timeout.C:
		// Notify and remove callbacks whose deadline is in the past.
		for el := plist.Front(); el != nil; el = el.Next() {
			p := el.Value.(*pending)
			if now.After(p.deadline) || now.Equal(p.deadline) {
				...
			}
		}
	}
}
</pre><p><strong>Fixed</strong> assuming time channels receive monotonic times as well.</p><h3><a class="h" name="k8s_io_heapster_metrics_sinks_manager_go_150" href="#k8s_io_heapster_metrics_sinks_manager_go_150"><span></span></a>k8s.io/heapster/metrics/sinks/manager.go:150</h3><pre class="code">startTime := time.Now()
...
defer exporterDuration.
	WithLabelValues(s.Name()).
	Observe(float64(time.Since(startTime)) / float64(time.Microsecond))
</pre><p><strong>Fixed.</strong></p><h3><a class="h" name="github_com_vmware_harbor_src_ui_auth_lock_go_43" href="#github_com_vmware_harbor_src_ui_auth_lock_go_43"><span></span></a>github.com/vmware/harbor/src/ui/auth/lock.go:43</h3><pre class="code">func (ul *UserLock) Lock(username string) {
	...
	ul.failures[username] = time.Now()
}
</pre><p>used by:</p><pre class="code">func (ul *UserLock) IsLocked(username string) bool {
	...
	return time.Now().Sub(ul.failures[username]) &lt;= ul.d
}
</pre><p><strong>Fixed.</strong></p><h3><a class="h" name="github_com_openshift_origin_vendor_k8s_io_kubernetes_pkg_kubectl_resource_printer_test_go_1410" href="#github_com_openshift_origin_vendor_k8s_io_kubernetes_pkg_kubectl_resource_printer_test_go_1410"><span></span></a>github.com/openshift/origin/vendor/k8s.io/kubernetes/pkg/kubectl/resource_printer_test.go:1410</h3><pre class="code">{&quot;an hour ago&quot;, translateTimestamp(unversioned.Time{Time: time.Now().Add(-6e12)}), &quot;1h&quot;},
</pre><p>where</p><pre class="code">func translateTimestamp(timestamp unversioned.Time) string {
	if timestamp.IsZero() {
		return &quot;&lt;unknown&gt;&quot;
	}
	return shortHumanDuration(time.Now().Sub(timestamp.Time))
}
</pre><p><strong>Fixed.</strong></p><h3><a class="h" name="github_com_pingcap_pd_server_kv_go_194" href="#github_com_pingcap_pd_server_kv_go_194"><span></span></a>github.com/pingcap/pd/server/kv.go:194</h3><pre class="code">start := time.Now()
resp, err := clientv3.NewKV(c).Get(ctx, key, opts...)
if cost := time.Since(start); cost &gt; kvSlowRequestTime {
	log.Warnf(&quot;kv gets too slow: key %v cost %v err %v&quot;, key, cost, err)
}
</pre><p><strong>Fixed.</strong></p><h3><a class="h" name="github_com_xtaci_kcp_go_sess_go_489" href="#github_com_xtaci_kcp_go_sess_go_489"><span></span></a>github.com/xtaci/kcp-go/sess.go:489</h3><pre class="code">if interval &gt; 0 &amp;&amp; time.Now().After(lastPing.Add(interval)) {
	...
	lastPing = time.Now()
}
</pre><p><strong>Fixed.</strong></p><h3><a class="h" name="github_com_go_xorm_xorm_lru_cacher_go_202" href="#github_com_go_xorm_xorm_lru_cacher_go_202"><span></span></a>github.com/go-xorm/xorm/lru_cacher.go:202</h3><pre class="code">el.Value.(*sqlNode).lastVisit = time.Now()
</pre><p>used as</p><pre class="code">if removedNum &lt;= core.CacheGcMaxRemoved &amp;&amp;
	time.Now().Sub(e.Value.(*idNode).lastVisit) &gt; m.Expired {
	...
}
</pre><p><strong>Fixed.</strong></p><h3><a class="h" name="github_com_openshift_origin_vendor_github_com_samuel_go_zookeeper_zk_conn_go_510" href="#github_com_openshift_origin_vendor_github_com_samuel_go_zookeeper_zk_conn_go_510"><span></span></a>github.com/openshift/origin/vendor/github.com/samuel/go-zookeeper/zk/conn.go:510</h3><pre class="code">conn.SetWriteDeadline(time.Now().Add(c.recvTimeout))
</pre><p><strong>Fixed.</strong></p><h3><a class="h" name="github_com_openshift_origin_vendor_k8s_io_kubernetes_pkg_client_leaderelection_leaderelection_go_236" href="#github_com_openshift_origin_vendor_k8s_io_kubernetes_pkg_client_leaderelection_leaderelection_go_236"><span></span></a>github.com/openshift/origin/vendor/k8s.io/kubernetes/pkg/client/leaderelection/leaderelection.go:236</h3><pre class="code">le.observedTime = time.Now()
</pre><p>used as:</p><pre class="code">if le.observedTime.Add(le.config.LeaseDuration).After(now.Time) &amp;&amp; ...
</pre><p><strong>Fixed.</strong></p><h3><a class="h" name="k8s_io_heapster_events_sinks_manager_go_139" href="#k8s_io_heapster_events_sinks_manager_go_139"><span></span></a>k8s.io/heapster/events/sinks/manager.go:139</h3><pre class="code">startTime := time.Now()
defer exporterDuration.
	WithLabelValues(s.Name()).
	Observe(float64(time.Since(startTime)) / float64(time.Microsecond))
</pre><p><strong>Fixed.</strong></p><h3><a class="h" name="golang_org_x_net_ipv4_unicast_test_go_64" href="#golang_org_x_net_ipv4_unicast_test_go_64"><span></span></a>golang.org/x/net/ipv4/unicast_test.go:64</h3><pre class="code">... p.SetReadDeadline(time.Now().Add(100 * time.Millisecond)) ...
</pre><p><strong>Fixed.</strong></p><h3><a class="h" name="github_com_kelseyhightower_confd_vendor_github_com_Sirupsen_logrus_text_formatter_go_27" href="#github_com_kelseyhightower_confd_vendor_github_com_Sirupsen_logrus_text_formatter_go_27"><span></span></a><a class="h" name="github_com_kelseyhightower_confd_vendor_github_com_sirupsen_logrus_text_formatter_go_27" href="#github_com_kelseyhightower_confd_vendor_github_com_sirupsen_logrus_text_formatter_go_27"><span></span></a>github.com/kelseyhightower/confd/vendor/github.com/Sirupsen/logrus/text_formatter.go:27</h3><pre class="code">func init() {
	baseTimestamp = time.Now()
	isTerminal = IsTerminal()
}

func miniTS() int {
	return int(time.Since(baseTimestamp) / time.Second)
}
</pre><p><strong>Fixed</strong> (same as above, vendored in docker/libnetwork).</p><h3><a class="h" name="github_com_openshift_origin_vendor_github_com_coreos_etcd_etcdserver_v3_server_go_693" href="#github_com_openshift_origin_vendor_github_com_coreos_etcd_etcdserver_v3_server_go_693"><span></span></a>github.com/openshift/origin/vendor/github.com/coreos/etcd/etcdserver/v3_server.go:693</h3><pre class="code">start := time.Now()
...
return nil, s.parseProposeCtxErr(cctx.Err(), start)
</pre><p>where</p><pre class="code">curLeadElected := s.r.leadElectedTime()
prevLeadLost := curLeadElected.Add(-2 * time.Duration(s.Cfg.ElectionTicks) * time.Duration(s.Cfg.TickMs) * time.Millisecond)
if start.After(prevLeadLost) &amp;&amp; start.Before(curLeadElected) {
	return ErrTimeoutDueToLeaderFail
}
</pre><p>All the times involved end up being monotonic, making the After/Before checks more accurate.</p><p><strong>Fixed.</strong></p></div></div></div><!-- default customFooter --><footer class="Site-footer"><div class="Footer"><span class="Footer-poweredBy">Powered by <a href="https://gerrit.googlesource.com/gitiles/">Gitiles</a>| <a href="https://policies.google.com/privacy">Privacy</a></span><div class="Footer-links"></div></div></footer></body></html>