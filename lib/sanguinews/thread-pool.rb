# Ruby Thread Pool
# ================
# A thread pool is useful when you wish to do some work in a thread, but do
# not know how much work you will be doing in advance. Spawning one thread
# for each task is potentially expensive, as threads are not free.
# 
# In this case, it might be more beneficial to start a predefined set of
# threads and then hand off work to them as it becomes available. This is
# the pure essence of what a thread pool is: an array of threads, all just
# waiting to do some work for you!
#
# Prerequisites
# -------------

# We need the [Queue](http://rdoc.info/stdlib/thread/1.9.2/Queue), as our
# thread pool is largely dependent on it. Thanks to this, the implementation
# becomes very simple!
require 'thread'

# Public Interface
# ----------------

# `Pool` is our thread pool class. It will allow us to do three operations:
# 
# - `.new(size)` creates a thread pool of a given size
# - `#schedule(*args, &job)` schedules a new job to be executed
# - `#shutdown` shuts down all threads (after letting them finish working, of course)
class Pool

  # ### initialization, or `Pool.new(size)`
  # Creating a new `Pool` involves a certain amount of work. First, however,
  # we need to define its’ `size`. It defines how many threads we will have
  # working internally.
  # 
  # Which size is best for you is hard to answer. You do not want it to be
  # too low, as then you won’t be able to do as many things concurrently.
  # However, if you make it too high Ruby will spend too much time switching
  # between threads, and that will also degrade performance!
  def initialize(size)
    # Before we do anything else, we need to store some information about
    # our pool. `@size` is useful later, when we want to shut our pool down,
    # and `@jobs` is the heart of our pool that allows us to schedule work.
    @size = size
    @jobs = Queue.new
    
    # #### Creating our pool of threads
    # Once preparation is done, it’s time to create our pool of threads.
    # Each thread store its’ index in a thread-local variable, in case we
    # need to know which thread a job is executing in later on.
    @pool = Array.new(@size) do |i|
      Thread.new do
        Thread.current[:id] = i

        # We start off by defining a `catch` around our worker loop. This
        # way we’ve provided a method for graceful shutdown of our threads.
        # Shutting down is merely a `#schedule { throw :exit }` away!
        catch(:exit) do
          # The worker thread life-cycle is very simple. We continuously wait
          # for tasks to be put into our job `Queue`. If the `Queue` is empty,
          # we will wait until it’s not.
          loop do
            # Once we have a piece of work to be done, we will pull out the
            # information we need and get to work.
            job, args = @jobs.pop
            job.call(*args)
          end
        end
      end
    end
  end
  
  # ### Work scheduling
  
  # To schedule a piece of work to be done is to say to the `Pool` that you
  # want something done.
  def schedule(*args, &block)
    # Your given task will not be run immediately; rather, it will be put
    # into the work `Queue` and executed once a thread is ready to work.
    @jobs << [block, args]
  end
  
  # ### Graceful shutdown
  
  # If you ever wish to close down your application, I took the liberty of
  # making it easy for you to wait for any currently executing jobs to finish
  # before you exit.
  def shutdown
    # A graceful shutdown involves threads exiting cleanly themselves, and
    # since we’ve defined a `catch`-handler around the threads’ worker loop
    # it is simply a matter of throwing `:exit`. Thus, if we throw one `:exit`
    # for each thread in our pool, they will all exit eventually!
    @size.times do
      schedule { throw :exit }
    end
    
    # And now one final thing: wait for our `throw :exit` jobs to be run on
    # all our worker threads. This call will not return until all worker threads
    # have exited.
    @pool.map(&:join)
  end
end

# Demonstration
# -------------
# Running this file will display how the thread pool works.
if $0 == __FILE__
  # - First, we create a new thread pool with a size of 10. This number is
  #   lower than our planned amount of work, to show that threads do not
  #   exit once they have finished a task.
  p = Pool.new(10)
  
  # - Next we simulate some workload by scheduling a large amount of work
  #   to be done. The actual time taken for each job is randomized. This
  #   is to demonstrate that even if two tasks are scheduled approximately
  #   at the same time, the one that takes less time to execute is likely
  #   to finish before the other one.
  20.times do |i|
    p.schedule do
      sleep rand(4) + 2
      puts "Job #{i} finished by thread #{Thread.current[:id]}"
    end
  end

  # - Finally, register an `at_exit`-hook that will wait for our thread pool
  #   to properly shut down before allowing our script to completely exit.
  at_exit { p.shutdown }
end

# License (X11 License)
# =====================
#
# Copyright (c) 2012, Kim Burgestrand <kim@burgestrand.se>
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
