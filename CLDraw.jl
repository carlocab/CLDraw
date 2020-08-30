using Random
using NamedArrays

#=
#   Write the team names of the teams that finished first in each group in `seeded`.
#   Do this in order of groups from A to H.
#
#   Then write the names of the teams who finished second in `unseeded` similarly.
#
#   Finally, make sure the teams you listed are included in the dictionaries containing
#   the teams from each country (i.e. `Spain`, `France`, etc.)
#
#   `simdraw(n)` generates an array where the j-th row and k-th column shows the number
#   of times in `n` simulations that the j-th seeded team meets the k-th unseeded team.
#   The i-th seeded (unseeded) team is the winner (runner-up) of the i-th group.
#
#   Run these simulations in Julia using
#
#       include("CLDraw.jl"); n = 10000; simdraw(n)
#
#   `simdraw_multhr(n)` is a multithreaded version of `simdraw(n)`. To simulate a single
#   draw, you can use `getdraw(seeded, unseeded, group, assoc)`.
=#

seeded = ["PSG", "Bayern", "Man City", "Juventus",
          "Liverpool", "Barcelona", "RB Leipzig", "Valencia"]
shortseed = ["PSG", "BAY", "MCI", "JUV", "LIV", "BAR", "RBL", "VAL"] # short names for seeded
unseeded = ["Real Madrid", "Tottenham", "Atalanta", "Atletico",
            "Napoli", "Dortmund", "Lyon", "Chelsea"]
shortuns = ["RMA", "TOT", "ATA", "ATL", "NAP", "DOR", "LYO", "CHL"] # short names for unseeded
groups = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H']

Spain = Dict(team => "ESP" for team in ["Real Madrid", "Barcelona", "Atletico", "Valencia"])
France = Dict(team => "FRA" for team in ["PSG", "Lyon"])
Germany = Dict(team => "GER" for team in ["Bayern", "RB Leipzig", "Dortmund"])
England = Dict(team => "ENG" for team in  ["Man City", "Liverpool", "Tottenham", "Chelsea"])
Italy = Dict(team => "ITA" for team in ["Juventus", "Napoli", "Atalanta"])

group = merge(Dict(seeded[i] => groups[i] for i in eachindex(seeded)),
              Dict(unseeded[i] => groups[i] for i in eachindex(unseeded)))
assoc = merge(Spain, France, Germany, England, Italy)

function matchable(team, opponent, group, assoc)
    # Checks if `team` and `opponent` are from different groups and associations.
    diffgroup = group[team] != group[opponent]
    diffassoc = assoc[team] != assoc[opponent]
    return diffgroup && diffassoc
end

function getmatches(team, seeded, unseeded, group, assoc)
    # Returns the possible opponents of `team`
    opponents = team in seeded ? unseeded : seeded
    # Check if `team` is `seeded` or `unseeded`
    matches = [opp for opp in opponents if matchable(team, opp, group, assoc)]
    return matches
end

function draw(team, seeded, unseeded, group, assoc)
    # Chooses an opponent randomly from the potential opponents
    possible = getmatches(team, seeded, unseeded, group, assoc)
    return rand(possible)
end

function getdraw(seeded, unseeded, group, assoc)
    # Takes the unmatched teams in `seeded` and `unseeded` and generates a random draw
    # according to CL rules.
    # 
    # When the unmatched teams impose no restrictions on the remaining matches,
    # an unseeded team is choosen (uniformly) at random. Then an opponent is chosen
    # (uniformly) at random from the eligible seeded teams.
    #
    # If there are two unseeded teams who can only face the same two seeded teams,
    # these two unseeded teams are matched first.
    if length(seeded) == 1 || length(unseeded) == 1
        # Chooses a random match if there is only one seeded or unseeded team remaining.
        # We have no guarantee that the match is legal (different groups / associations).
        # Uncomment the line before `return Dict(home => away)` to generate a warning
        # for illegal matches.
        home = rand(unseeded)
        away = rand(seeded)
        #matchable(home, away, group, assoc) || @warn("Illegal match.")
        return Dict(home => away)
    end
    seedopps = map(x -> getmatches(x, seeded, unseeded, group, assoc), seeded)
    # Create a vector of the possible opponents of unmatched seeded teams.
    unopps = map(x -> getmatches(x, seeded, unseeded, group, assoc), unseeded)
    # Create a vector of possible opponents of unmatched unseeded teams.
    nseedopps = size.(seedopps, 1)
    # Count the possible opponents of each seeded team.
    nunopps = size.(unopps, 1)
    # Count the possible opponents of each unseeded team.
    oneseedopp = findfirst(isequal(1), nseedopps)
    # Checks if a seeded team has only one possible opponent.
    # Returns `nothing` if a seeded team has multiple possible opponents.
    oneunopp = findfirst(isequal(1), nunopps)
    # Checks if an unseeded team has only one possible opponent.
    # Returns `nothing` if an unseeded team has multiple possible opponents.
    if isnothing(oneseedopp) && isnothing(oneunopp)
        # Checks whether each team has multiple possible opponents.
        twounopps = findall(isequal(2), nunopps)
        if !allunique(unopps[twounopps])
            # If two teams have the same two possible opponents,
            # then these two pairs must face each other.
            #twounopp = findfirst(isequal(2), nunopps)
            #home = unseeded[twounopp]
            # Choose a team at random from the pair of unseeded teams.
            home = rand(unseeded[twounopps])
        else
            # Choose one team randomly from `unseeded`.
            home = rand(unseeded)
        end
        away = draw(home, seeded, unseeded, group, assoc)
    elseif isnothing(oneseedopp)
        # An unseeded team has only one possible opponent.
        home = unseeded[oneunopp]
        away = draw(home, seeded, unseeded, group, assoc)
    else
        # A seeded team has only one possible opponent.
        away = seeded[oneseedopp]
        home = draw(away, seeded, unseeded, group, assoc)
    end
    newunseed = filter(!isequal(home), unseeded)
    newseed = filter(!isequal(away), seeded)
    # Removes the matched teams from `seeded` and `unseeded`.
    tie = Dict(home => away)
    return merge(tie, getdraw(newseed, newunseed, group, assoc))
    # Recursively calls itself on the remaining unmatched teams.
end

function simdraw(n, seeded=seeded, unseeded=unseeded, group=group, assoc=assoc)
    count = zeros(Int, length(seeded), length(unseeded))
    for ii in 1:n
        #tempseeded = copy(seeded)
        #tempun = copy(unseeded)
        draw = getdraw(seeded, unseeded, group, assoc)
        for jj in eachindex(unseeded)
            count[:,jj] += draw[unseeded[jj]] .== seeded
        end
    end
    return count
end

function simdraw_multhr(n, seeded=seeded, unseeded=unseeded, group=group, assoc=assoc)
    nseeds = length(seeded)
    nunseeds = length(unseeded)
    count = zeros(Int, nseeds, nunseeds, Threads.nthreads())
    Threads.@threads for ii in 1:n
        draw = getdraw(seeded, unseeded, group, assoc)
        for jj in eachindex(unseeded)
            count[:,jj,Threads.threadid()] += draw[unseeded[jj]] .== seeded
        end
    end
    return dropdims(sum(count, dims=3); dims=3)
end

function showteams(data, seeded=shortseed, unseeded=shortuns)
    return NamedArray(data, (seeded, unseeded), ("Away", "Home"))
end

