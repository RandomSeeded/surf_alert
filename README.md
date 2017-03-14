#Emails for when the surf's up

##What does v0 look like?

- just a single spot (easily extensible to be multiple spots later)
- a single amount of advance notice (say noon day before?, can extend to make multiple amounts of advance notice later)
- single criteria (fair to good or better)
- enter in email address
- sends you an email if the surf meets the criteria
- unsubscribe (removes all alerts)

##IMPLEMENTATION - v0

- ~~static webpage (for now), with a single form (input email), with placeholder (one option) for spot selection~~
- ~~erlang webserver which~~
  - ~~serves static webpage~~
  - ~~has route for email adding~~
  - ~~has database (file?) for email address storing~~
- cronjob (language? probably still erlang for sake of learning)
  - ~~hits surfline API~~
  - ~~checks if criteria are met~~
  - ~~sends emails~~

##IMPROVEMENTS

- spot search (nobody likes having to do the shit select from region nonsense)
- multiple spots
- accounts
- manage my alerts
- not having to re-enter email addr over and over again
- email verification?
- specify your own criteria for alerts
- change how much advanced notice you want for alerts

##NEXT STEPS
- **email sending should be turned into its own process instead of a script**
  - note that when using scripts/src must run with erl -pa ../ebin ../deps/*/ebin
- job which wraps checking the API and sending emails
  - We check the API, and if it's good, we continue by:
    - reading emails from mongo
    - spinning up multiple email sending processes in parallel, each of which sends an email to the recipient
- one issue: sending emails requires reading from Mongo, which is interesting because the mongo handler is in a separate directory. Figure out how to best handle this

##MISC

Factor out the surfline API checker to be its own process. Options:
1) Run itself on repeat and save to cache, when invoked retrieve from cache
2) Don't run on repeat, but save to cache, when invoked re-fetch if cache too old

What's the point? Are they really different than just running the whole job periodically?
- we can fallback to cache in case the API changes on us
- we can factor all the icky dealing with surfline API logic out into a separate process and therefore not break everything if we don't happy path

