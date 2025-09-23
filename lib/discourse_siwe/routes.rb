# frozen_string_literal: true

DiscourseSiwe::Engine.routes.draw do
  get  "/message"  => "auth#message"
  post "/callback" => "auth#callback"
end
