FROM ruby:2.6

WORKDIR /usr/src/app

COPY . .

CMD ["ruby", "./server.rb"]
