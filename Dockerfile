# Base image
FROM jekyll/jekyll:latest

# Set the working directory
WORKDIR /site

# Install dependencies
COPY Gemfile .
COPY Gemfile.lock .
RUN bundle install

# Expose the default Jekyll port
EXPOSE 4000

# Start Jekyll server
CMD ["jekyll", "serve"]
