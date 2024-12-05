FROM elixir:1.15-otp-24-alpine

RUN apk add bash python3 npm && npm install typescript -g

WORKDIR /taskir

COPY mix.exs mix.lock .

RUN mix deps.get

COPY . .

RUN mix

ENTRYPOINT ["mix", "run", "taskir.exs"]
