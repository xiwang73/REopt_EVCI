# *********************************************************************************
# REopt, Copyright (c) 2019-2020, Alliance for Sustainable Energy, LLC.
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without modification,
# are permitted provided that the following conditions are met:
#
# Redistributions of source code must retain the above copyright notice, this list
# of conditions and the following disclaimer.
#
# Redistributions in binary form must reproduce the above copyright notice, this
# list of conditions and the following disclaimer in the documentation and/or other
# materials provided with the distribution.
#
# Neither the name of the copyright holder nor the names of its contributors may be
# used to endorse or promote products derived from this software without specific
# prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
# IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
# INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
# BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
# LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
# OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
# OF THE POSSIBILITY OF SUCH DAMAGE.
# *********************************************************************************

struct Wind <: AbstractTech
    min_kw::Float64
    max_kw::Float64
    installed_cost_per_kw::Float64
    om_cost_per_kw::Float64
    prod_factor_series_kw::Union{Missing, Array{Real,1}}
    size_class::String
    hub_height::Float64
    wind_meters_per_sec::AbstractArray{Float64,1}
    wind_direction_degrees::AbstractArray{Float64,1}
    temperature_celsius::AbstractArray{Float64,1}
    pressure_atmospheres::AbstractArray{Float64,1}
    macrs_option_years::Int
    macrs_bonus_pct::Float64
    macrs_itc_reduction::Float64
    federal_itc_pct::Float64
    federal_rebate_per_kw::Float64
    state_ibi_pct::Float64
    state_ibi_max::Float64
    state_rebate_per_kw::Float64
    state_rebate_max::Float64
    utility_ibi_pct::Float64
    utility_ibi_max::Float64
    utility_rebate_per_kw::Float64
    utility_rebate_max::Float64
    production_incentive_per_kwh::Float64
    production_incentive_max_benefit::Float64
    production_incentive_years::Int
    production_incentive_max_kw::Float64

    function Wind(;
        min_kw = 0.0,
        max_kw = 1.0e9,
        installed_cost_per_kw = 3013.0,
        om_cost_per_kw = 40.0,
        prod_factor_series_kw = missing,
        size_class = "",
        wind_meters_per_sec = [],
        wind_direction_degrees = [],
        temperature_celsius = [],
        pressure_atmospheres = [],
        macrs_option_years = 5,
        macrs_bonus_pct = 0.0,
        macrs_itc_reduction = 0.5,
        federal_itc_pct = 0.26,
        federal_rebate_per_kw = 0.0,
        state_ibi_pct = 0.0,
        state_ibi_max = 1.0e10,
        state_rebate_per_kw = 0.0,
        state_rebate_max = 1.0e10,
        utility_ibi_pct = 0.0,
        utility_ibi_max = 1.0e10,
        utility_rebate_per_kw = 0.0,
        utility_rebate_max = 1.0e10,
        production_incentive_per_kwh = 0.0,
        production_incentive_max_benefit = 1.0e9,
        production_incentive_years = 1,
        production_incentive_max_kw = 1.0e9,
        )
        size_class_to_hub_height = Dict(
            "residential"=> 20,
            "commercial"=> 40,
            "medium"=> 60,  # Owen Roberts provided 50m for medium size_class, but Wind Toolkit has increments of 20m
            "large"=> 80
        )
        size_class_to_installed_cost = Dict(
            "residential"=> 11950.0,
            "commercial"=> 7390.0,
            "medium"=> 4440.0,
            "large"=> 3450.0
        )

        size_class_to_itc_incentives = Dict(
            "residential"=> 0.3,
            "commercial"=> 0.3,
            "medium"=> 0.12,
            "large"=> 0.12
        )
        """
        If the size_class is not provided then it is determined by average load. 
        """
        if length(size_class) == 0
            size_class = "large"
        elseif !(size_class in keys(size_class_to_hub_height))
            @error "Wind.size_class must be one of $(keys(size_class_to_hub_height))"
        end

        hub_height = size_class_to_hub_height[size_class]

        new(
            min_kw,
            max_kw,
            installed_cost_per_kw,
            om_cost_per_kw,
            prod_factor_series_kw,
            size_class,
            hub_height,
            wind_meters_per_sec,
            wind_direction_degrees,
            temperature_celsius,
            pressure_atmospheres,
            macrs_option_years,
            macrs_bonus_pct,
            macrs_itc_reduction,
            federal_itc_pct,
            federal_rebate_per_kw,
            state_ibi_pct,
            state_ibi_max,
            state_rebate_per_kw,
            state_rebate_max,
            utility_ibi_pct,
            utility_ibi_max,
            utility_rebate_per_kw,
            utility_rebate_max,
            production_incentive_per_kwh,
            production_incentive_max_benefit,
            production_incentive_years,
            production_incentive_max_kw
        )
    end
end