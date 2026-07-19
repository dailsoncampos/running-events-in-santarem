FROM ruby:3.2.2

# Instalar dependências do sistema
RUN apt-get update -qq && apt-get install -y \
    nodejs \
    npm \
    postgresql-client \
    build-essential \
    libsqlite3-dev \
    && rm -rf /var/lib/apt/lists/*

# Configurar diretório de trabalho
WORKDIR /app

# Copiar Gemfile e Gemfile.lock
COPY Gemfile* ./

# Instalar gems
RUN bundle install

# Copiar o resto da aplicação
COPY . .

# Expor porta 3000
EXPOSE 3000

# Comando padrão
CMD ["rails", "server", "-b", "0.0.0.0"]
