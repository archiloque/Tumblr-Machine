# Tumblr Machine

A Tumblr feedreader and reblogging tool written in ruby.

Setup a list of interesting tags with a score and it will pull new posts from the tags and display the ones with the highest score, and you'll be able to reblog the one you likes with a single click.

Can process the linked images to eliminates duplicates (see bellow).

Code should be easy to hack on, contact me for any question.

# Instructions

- deploy the application on your server
- set the environment variables (see bellow)
- connect to the server (the databse structure will be created automatically) and setup the tags

# Environment variables

- email the email to connect to tumblr
- password same thing
- tumblr_name your tumblr's name
- openid_uri the openid uri for authentication
- DATABASE_URL database url, syntax is described [here](http://sequel.rubyforge.org/rdoc/files/doc/opening_databases_rdoc.html), remember to add the required database gem
- deduplication: enable image deduplication through the [Phashion](https://github.com/mperham/phashion) gem, requires GraphicsMagick or ImageMagick and a database with the hamming function (to calculate similarity between images). The current code works with PostgreSQl and requires installing the [pg_similarity](http://pgsimilarity.projects.postgresql.org/) package.

# LICENSE

Except files with their own copyright license:

Copyright (c) 2011, Julien Kirch
All rights reserved.

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the
following conditions are met:

Redistributions of source code must retain the above copyright notice, this list of conditions and the following
disclaimer.
Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following
disclaimer in the documentation and/or other materials provided with the distribution.
Neither the name of BiteScript nor the names of its contributors may be used to endorse or promote products derived from
this software without specific prior written permission.
THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES,
INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.