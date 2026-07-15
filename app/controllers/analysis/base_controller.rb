# frozen_string_literal: true

module Analysis
  # Shared parent for the read-only listings built on top of AnalysisResult
  # (player rankings, and future pages like map balance / activity
  # breakdowns). Nothing shared yet beyond the namespace itself, but new
  # cross-cutting concerns (caching, layout tweaks, auth) belong here instead
  # of being duplicated across each Analysis:: controller.
  class BaseController < ApplicationController
  end
end
