import Pkg; Pkg.activate(".")

using Plots
using StatsPlots
import CSV
using Distributions
using Statistics
using StatsBase
using Random

# include functions
include("common_functions.jl")

Plots.scalefontsizes(1.3)
fonts=font("Arial",7)

# get the data and filter for predation only
d = CSV.read(joinpath("data", "network_data.dat"))
d = d[d.predation .> 0 , :]


# color palette for models
pal = (
    lssl=RGB(230/255,159/255,0/255),
    cc=RGB(86/255,190/255,233/255),
    pl=RGB(0/255,158/255,115/255),
    fl=RGB(204/255,121/255,167/255)
    )


# posterior samples for the flexible links model
betab_posterior = CSV.read(joinpath("data", "posterior_distributions", "beta_binomial_posterior.csv"))

# posterior samples from previous models
lssl_posterior = CSV.read(joinpath("data", "posterior_distributions", "lssl.csv"))
const_posterior = CSV.read(joinpath("data", "posterior_distributions", "const_posterior.csv"))
powerlaw_posterior = CSV.read(joinpath("data", "posterior_distributions", "powerlaw_posterior.csv"))


# number of species
S = 3:750
mms = S.-1 # min links
Ms = S.^2 # max links
ms = mms ./ Ms  # min connectance
msl = (S .- 1) ./ (S) # min link density
total_flex = S .^ 2 .-S .+1

# map estimates
mu_map = median(betab_posterior[:mu])
phi_map = exp(median(betab_posterior[:phi]))

α = mu_map*phi_map
β = (1.0-mu_map)*phi_map

beta_map = Beta(α, β)
betabin_map = BetaBinomial.(total_flex, α, β)


# counterfactuals
betab_cf_links = betab_posterior[r"counterfactual_links"]
betab_cf_links = betab_cf_links[:, S]

lssl_cf_links = lssl_posterior[r"counterfactual_links"]
lssl_cf_links = lssl_cf_links[:, S]

const_cf_links = const_posterior[r"counterfactual_links"]
const_cf_links = const_cf_links[:, S]

powerlaw_cf_links = powerlaw_posterior[r"counterfactual_links"]
powerlaw_cf_links = powerlaw_cf_links[:, S]

# Fig -- Parameters can be estimated by Maximum Likelihood

# generate posterior draws of the Beta distribution
Random.seed!(1234)
index = rand(1:size(betab_posterior,2), 20) # 20 posterior samples
mu_rdm = betab_posterior[index, :mu]
phi_rdm = exp.(betab_posterior[index, :phi])

betab_random = Beta.(mu_rdm .* phi_rdm, (1 .- mu_rdm) .* phi_rdm)

# MLE fit
pex = (d.links .- (d.nodes .- 1)) ./  (d.nodes.^2 .- (d.nodes .- 1))

p = fit(Beta, pex)

# calculate for text
phi_MLE = p.α + p.β
mu_MLE = p.α / phi_MLE

density(pex, c=:lightgrey, fill=(:lightgrey, 0, 0.5), dpi=1000, size=(800,500),  margin=5Plots.mm, lab="Empirical data",
    foreground_color_legend=nothing, background_color_legend=:white, framestyle=:box,
    guidefont=fonts, xtickfont=fonts, ytickfont=fonts, legendfont=fonts)
plot!(betab_random[1], c=pal.fl, linewidth=1, alpha=0.3, lab="Posterior samples")
for i in 1:length(index)
    plot!(betab_random[i], c=pal.fl, linewidth=1, alpha=0.3, lab="")
end
density!(rand(p, 100_000), c=:black, ls=:dash, linewidth=2, lab="MLE fit")
yaxis!((0, 9.5), "Density")
xaxis!((0, 0.5), "p")
savefig(joinpath("figures", "beta_fit"))


# Fig -- The fexible link model ts better and makes a plausible range of predictions

# To make the maximum point apparent in plot
d.nodesmax = maximum(d.nodes)
d.linksmax = maximum(d.links)

# Function to plot the quantiles of the counterfactuals links of each model
# we use log_zeros function to plot the y-axis in log (to account for log(0))
function plot_links_quantile(model; title="", xlabel="", ylabel="", linecolor="")
    quant_015 = neg_to_zeros.(quantile.(eachcol(model), 0.015))
    quant_110 = neg_to_zeros.(quantile.(eachcol(model), 0.11))
    quant_890 = neg_to_zeros.(quantile.(eachcol(model), 0.89))
    quant_985 = neg_to_zeros.(quantile.(eachcol(model), 0.985))
    quant_500 = neg_to_zeros.(quantile.(eachcol(model), 0.5))

    plot(S, quant_985, fill=quant_015, color=:grey, alpha=0.15, label="",
        title=title, title_location=:left,
        xlabel=xlabel, ylabel=ylabel, framestyle=:box, dpi=1000,
        guidefont=fonts, xtickfont=fonts, ytickfont=fonts, titlefont=font("Arial",9)) # 97% PI
    plot!(S, quant_890, fill=quant_110, color=:grey, alpha=0.15, label="") # 89% PI
    scatter!(d[:nodes], d[:links], c=:grey, alpha=0.6, msw=0, markersize=5, label="") # Empirical links
    plot!(S, quant_500, linecolor=linecolor, linewidth=3, label="") # Median link number
    scatter!(d.nodesmax, d.linksmax, c=:grey, alpha=0.6, msw=0, markersize=5, label="") # Maximum empirical link
    plot!(S, mms, linecolor=:black, lw=1, label="") # Minimum number of links
    plot!(S, Ms, linecolor=:black, lw=2, label="") # Maximum number of links
    xaxis!(:log, xlabel=xlabel, xlims=(minimum(S), maximum(S)))
    yaxis!(:log, ylims = (1,100000), ylabel=ylabel)
end

plot_lssl = plot_links_quantile(lssl_cf_links, title="A. LSSL",
    ylabel="Number of links", linecolor=pal.lssl)
plot_const = plot_links_quantile(const_cf_links, title="B. Constant connectance",
    linecolor=pal.cc)
plot_powerlaw = plot_links_quantile(powerlaw_cf_links, title="C. Power law",
    xlabel="Species richness", ylabel="Number of links", linecolor=pal.pl)
plot_betab = plot_links_quantile(betab_cf_links, title="D. Flexible links",
    xlabel="Species richness", linecolor=pal.fl)

plot(plot_lssl, plot_const, plot_powerlaw, plot_betab, layout=(2,2), size=(700,700),  margin=5Plots.mm, dpi=200)
savefig(joinpath("figures", "models_links"))
savefig(joinpath("figures", "submission", "fig1.pdf"))



# Fig -- The shifted beta-binomial distribution can be approximated by a normal distribution

# A BetaBinomial predictions from map values

bb_rand = rand.(betabin_map, 5000)

beta_89 = quantile.(bb_rand, 0.89) .+ S .- 1
beta_11 = quantile.(bb_rand, 0.11) .+ S .- 1
beta_98 = quantile.(bb_rand, 0.985) .+ S .- 1
beta_02 = quantile.(bb_rand, 0.015) .+ S .- 1
beta_50 = quantile.(bb_rand, 0.5)  .+ S .- 1

links_beta_map = plot(S, beta_98, fill=beta_02,label="", color=:grey, alpha=0.15,
    title="A. Flexible links (MAP)", title_location=:left, framestyle=:box,
    guidefont=fonts, xtickfont=fonts, ytickfont=fonts, titlefont=font("Arial",9))
plot!(S, beta_89, fill=beta_11,label="", color=:grey, alpha=0.15)
plot!(S, beta_50, color=pal.fl, label="", linewidth=2)
#scatter!(d[:nodes], d[:links], c=:grey, msw=0, markersize=5, label="") # Empirical links
plot!(S, mms, linecolor=:black, label="", lw=1) # Minimum number of links
plot!(S, Ms, linecolor=:black, label="", lw=2) # Maximum number of links
xaxis!(:log, "Species richness", label="", xlim=(minimum(S), maximum(S)))
yaxis!(:log, "Number of links", ylims=(1,100000))

# B Normal approximation of BetaBinomial
means = (Ms .- mms) .* mu_map .+ S .- 1
vars = (Ms .- mms) .* mu_map .* (1 .- mu_map) .* (1 .+ S .* (S .- 1) .* (1 / (1 + phi_map)))

approxs = Normal.(means, sqrt.(vars))
tnormal = truncated.(approxs, 0.01, Inf)

tnormal_89 = quantile.(tnormal, 0.89)
tnormal_11 = quantile.(tnormal, 0.11)
tnormal_98 = quantile.(tnormal, 0.985)
tnormal_02 = quantile.(tnormal, 0.015)
tnormal_50 = quantile.(tnormal, 0.5)

links_normal = plot(S, tnormal_98, fill=tnormal_02,label="", color=:grey, alpha=0.15,
    title="B. Normal approximation", title_location=:left, framestyle=:box,
    guidefont=fonts, xtickfont=fonts, ytickfont=fonts, titlefont=font("Arial",9))
plot!(S, tnormal_89, fill=tnormal_11,label="", color=:grey, alpha=0.15,)
plot!(S, tnormal_50, color=pal.fl, label="", lw=2)
plot!(S, mms, linecolor=:black, label="", lw=1) # Minimum number of links
plot!(S, Ms, linecolor=:black, label="", lw=2) # Maximum number of links
#scatter!(d[:nodes], d[:links], label="", color=:grey) # Empirical links
xaxis!(:log, "Species richness", label="", xlim=(minimum(S), maximum(S)))
yaxis!(:log, "Number of links", ylims=(1,100000))

plot(links_beta_map, links_normal, layout=(1,2), size=(700,350), margin=5Plots.mm, dpi=1000)
savefig(joinpath("figures", "betabinmap_normal_links"))
savefig(joinpath("figures", "submission", "fig5.pdf"))




# Fig - Connectance and linkage density can be derived from a model for links

# A - connectance - species

## scale the "expected" distribution according to the minimum value:
bquant = LocationScale.(ms, 1 .- ms, beta_map)

# Quantiles to plot
beta015 = quantile.(bquant, 0.015)
beta985 = quantile.(bquant, 0.985)
beta11 = quantile.(bquant, 0.110)
beta89 = quantile.(bquant, 0.890)

beta500 = quantile.(bquant, 0.5)

# Empirical connectance
co_emp = d[:links] ./ (d[:nodes] .^2)


# Connectance vs species
connectance_beta = plot(S, beta985, fillrange=beta015, color=:grey, alpha=0.15,
    label="", title="A", title_location=:left, framestyle=:box,
    guidefont=fonts, xtickfont=fonts, ytickfont=fonts, titlefont=font("Arial",9)) # 97% PI
plot!(S, beta11, fillrange=beta89, color=:grey, alpha=0.15, label="") # 89% PI
scatter!(d[:nodes], co_emp, c=:grey, alpha=0.5, msw=0, markersize=5, label="") # Empirical connectance
plot!(S, beta500, linecolor=pal.fl, linewidth=2, label="") # Median connectance
plot!(S, ms, label="", linecolor=:black, lw=1) # Minimum connectance
xaxis!(:log, "Species richness", xlims=(minimum(S),maximum(S)))
yaxis!("Connectance", (0, 0.5))

# B linkage density - species

## scale the "expected" distribution according to the mimum value:
bquant_LS = LocationScale.(msl, S .- msl, beta_map)

beta015_LS = quantile.(bquant_LS, 0.015)
beta985_LS = quantile.(bquant_LS, 0.985)
beta11_LS = quantile.(bquant_LS, 0.11)
beta89_LS = quantile.(bquant_LS, 0.89)
beta50_LS = quantile.(bquant_LS, 0.50)

avg_degree_beta = plot(S, beta985_LS, fill=beta015_LS, color=:grey, alpha=0.15, lab="", title="B",
    title_location=:left, framestyle=:box,
    guidefont=fonts, xtickfont=fonts, ytickfont=fonts, titlefont=font("Arial",9))
plot!(S, beta11_LS, fill=beta89_LS, colour=:grey, alpha=0.15, lab="",)
scatter!(d.nodes, d.links ./ d.nodes, c=:grey, alpha=0.5, msw=0, markersize=5, label="") # Empirical connectance
plot!(S, beta50_LS, linecolor=pal.fl, lw=2, lab="")
plot!(S, msl, linecolor=:black, lw=1, lab="")
plot!(S, S, linecolor=:black, lw=2, lab="")
xaxis!(:log, "Species richness", xlims=(minimum(S),maximum(S)))
yaxis!(:log, "Linkage density", ylims=(0.5,1000))


plot(connectance_beta, avg_degree_beta, label=(1,2), lab="", size=(700,350),  dpi=1000,  margin=5Plots.mm)
savefig(joinpath("figures", "connectance_linkdens"))
savefig(joinpath("figures", "submission", "fig3.pdf"))



# Fig -- Only the flexible link model makes realistic predictions for small communities

function realistic_links(model_cf)
    realistic = zeros(Float64, (1, length(S)))
    for (i,s) in enumerate(S)
        belowmin = length(findall(model_cf[:,i] .< (s - 1)))
        abovemax = length(findall(model_cf[:,i] .> (s^2)))
        realistic[i] = 1 - (belowmin + abovemax) / size(model_cf, 1)
    end
    return(vec(realistic))
end

realistic_betab =  realistic_links(betab_cf_links)
realistic_lssl = realistic_links(lssl_cf_links)
realistic_const = realistic_links(const_cf_links)
realistic_powerlaw = realistic_links(powerlaw_cf_links)


medianspecies = quantile(d[:nodes], 0.5)
species05 = quantile(d[:nodes], 0.05)
species95 = quantile(d[:nodes], 0.95)

plot([medianspecies], seriestype=:vline, color=:grey, ls=:dash, lab="", ylim=(0.4,1), frame=:box,  margin=5Plots.mm,
    guidefont=fonts, xtickfont=fonts, ytickfont=fonts, legendfont=fonts, titlefont=font("Arial",9))
plot!([species05, species95], [1.0, 1.0], fill=(0, :grey, 0.12), c=:transparent, lab="")
plot!([species05], seriestype=:vline, color=:grey, ls=:dot, lab="")
plot!([species95], seriestype=:vline, color=:grey, ls=:dot, lab="")
plot!(S, realistic_lssl, color=pal.lssl, linewidth=2, label="LSSL",
    legend=:bottomright, foreground_color_legend=nothing, background_color_legend=:white)
plot!(S, realistic_const, color=pal.cc, linewidth=2, label="Constant connectance")
plot!(S, realistic_powerlaw, color=pal.pl, linewidth=2, label="Power law")
plot!(S, realistic_betab, color=pal.fl, linewidth=2, label="Flexible links")
xaxis!(:log, "Species richness", xlims=(minimum(S),maximum(S)))
yaxis!("Proportion of realistic links", (0.3, 1.01))
savefig(joinpath("figures", "real_predict"))
savefig(joinpath("figures", "submission", "fig2.pdf"))



# Fig -- Many different Network-Area Relationships are supported by the data
A = 0.0001:0.02:1.2
k,z = 200.0, 0.27
AS = convert.(Int64, ceil.(k.*A.^z))

pl_nar_sar = plot(A, AS, color=:grey, lw=2, label="", frame=:box,
    legend=:topleft, foreground_color_legend=nothing, background_color_legend=:white,
    title_location=:left, guidefont=fonts, xtickfont=fonts, ytickfont=fonts, legendfont=fonts, titlefont=font("Arial",9),
    title="A. species area relationship")

xaxis!(pl_nar_sar, (0, 1), "Relative area")
yaxis!(pl_nar_sar, (0, 200), "Species richness")

# extract counterfactual links only -- necessary so that position matches S
bb_post = betab_posterior[r"counterfactual_links"]
pl_post = powerlaw_posterior[r"counterfactual_links"]
# extract columns matching species richness from AS
pl_mod = pl_post[:,AS]
fl_mod = bb_post[:,AS]

pl500 = neg_to_zeros.(quantile.(eachcol(pl_mod./AS'), 0.5))

fl015 = neg_to_zeros.(quantile.(eachcol(fl_mod./AS'), 0.015))
fl110 = neg_to_zeros.(quantile.(eachcol(fl_mod./AS'), 0.11))
fl890 = neg_to_zeros.(quantile.(eachcol(fl_mod./AS'), 0.89))
fl985 = neg_to_zeros.(quantile.(eachcol(fl_mod./AS'), 0.985))
fl500 = neg_to_zeros.(quantile.(eachcol(fl_mod./AS'), 0.5))

pl_nar_nar = plot(A, fl985, fillrange=fl015, color=:grey, alpha=0.15, label="", frame=:box, legend=:topleft, foreground_color_legend=nothing, background_color_legend=:white,
    title_location=:left, guidefont=fonts, xtickfont=fonts, ytickfont=fonts, legendfont=fonts, titlefont=font("Arial",9),
    title="B. network area relationship")
plot!(pl_nar_nar, A, fl890, fillrange=fl110, color=:grey, alpha=0.15, label="")
plot!(pl_nar_nar, A, fl500, linecolor=pal.fl, linewidth=2, label="Flexible links")
plot!(pl_nar_nar, A, pl500, linecolor=pal.pl, linewidth=1, ls=:dot, label="Power law")
xaxis!(pl_nar_nar, xlabel="Relative area", xlims=(0.0, 1.0))
yaxis!(pl_nar_nar, ylims = (1,50), ylabel="Linkage density")

plot(pl_nar_sar, pl_nar_nar, layout=(1,2), size=(700,350), margin=5Plots.mm, dpi=1000)
savefig(joinpath("figures", "nar"))
savefig(joinpath("figures", "submission", "fig6.pdf"))



# Fig -- Stability imposes a limit on network size
# posterior samples for the flexible links model
betab_posterior_bigger = CSV.read(joinpath("data", "posterior_distributions", "beta_binomial_posterior_bigger.csv"))

# stability after May / Allesina & Tang
S = 1:1500
fl_mod = betab_posterior_bigger[:,r"counterfactual_links"]

fl015 = neg_to_zeros.(quantile.(eachcol(fl_mod./S'), 0.015))
fl110 = neg_to_zeros.(quantile.(eachcol(fl_mod./S'), 0.11))
fl890 = neg_to_zeros.(quantile.(eachcol(fl_mod./S'), 0.89))
fl985 = neg_to_zeros.(quantile.(eachcol(fl_mod./S'), 0.985))
fl500 = neg_to_zeros.(quantile.(eachcol(fl_mod./S'), 0.5))

pl_may_max = plot(S, vec(1.0./sqrt.(fl985)), fillrange=vec(1.0./sqrt.(fl015)),
    color=:grey, alpha=0.15, label="", frame=:box, size=(400, 400), margin=5Plots.mm,
    dpi=1000, legend=:topleft, foreground_color_legend=nothing,
    title_location=:left, guidefont=fonts, xtickfont=fonts, ytickfont=fonts, legendfont=fonts, titlefont=font("Arial",9),
    title="A. maximal interaction diversity",
    background_color_legend=:white,
    xlabel="Species richness", ylabel="Maximal \\sigma")
plot!(pl_may_max, S, vec(1.0./sqrt.(fl890)), fillrange=vec(1.0./sqrt.(fl110)), color=:grey, alpha=0.15, label="")
plot!(pl_may_max, S, vec(1.0./sqrt.(fl500)), lw=2, c=pal.fl, lab="")
xaxis!(pl_may_max, :log, (3,1000))
plot!(pl_may_max, S, sqrt.(S)./sqrt.(S.-1), lab="", colour = :black, lw=1)
plot!(pl_may_max, S, 1.0 ./sqrt.(S), lab="", colour = :black, lw = 2)
yaxis!(pl_may_max, (0,1.25), label="Maximal interaction diversity")
# expression for the mean.
mu_map = median(betab_posterior_bigger[:mu])
plot!(pl_may_max, S, 1 ./ sqrt.(mu_map .* S .+ (1 - mu_map) .* (S .- 1) ./ S), lab = "", color=:black, lw = 1, linestyle=:dash)

pl_may_prop = plot(frame=:box, title_location=:left,
    guidefont=fonts, xtickfont=fonts, ytickfont=fonts, legendfont=fonts, titlefont=font("Arial",9),
    title="B. probability of a network being stable",
    foreground_color_legend=nothing,
    background_color_legend=:white)

σ = 0.0:0.01:1.25


for s in [10, 30, 100, 300, 1000]
    L = fl_mod[:,s]
    m = sqrt.(s.*(L./(s^2)))
    plot!(pl_may_prop, σ, sum((σ.*m').< 1, dims=2)./2000, lab="", lw=log(s)/log(1000).*3, c=:grey, fill=(0, :darkgrey, 0.05))
end

yaxis!(pl_may_prop, (0,1), "P(stability)")
xaxis!(pl_may_prop, "\\sigma", (minimum(σ), maximum(σ)))

plot(pl_may_max, pl_may_prop, layout=(1,2), size=(700,350), margin=5Plots.mm, dpi=1000)
savefig(joinpath("figures", "may"))
savefig(joinpath("figures", "submission", "fig7.pdf"))




# Fig -- Histogram of z-scores

# Compute expected number of links and variance
L_hat = (d.nodes .^2 .- d.nodes .+ 1) .* mu_map .+ d.nodes .- 1
sigma_2_L_hat = (d.nodes .^2 .- d.nodes .+ 1) .* mu_map .* (1 .- mu_map) .* (1 .+ d.nodes .* (d.nodes .- 1) ./ (phi_map .+ 1))

# Compute z-scores
z_scores = (d.links .- L_hat) ./ sqrt.(sigma_2_L_hat)

# Non abnormal z-scores (below 1.96 in absolute values)
z_scores_normals = z_scores[abs.(z_scores) .< 1.96]

# Abnormal z-scores (above 1.96 in absolute values)
z_scores_abnormals = z_scores[abs.(z_scores) .> 1.96]
z_scores_abnormals_pct = length(z_scores_abnormals) / size(d, 1)

# Plot histogram
histogram(z_scores_normals, lab="", fill=:lightgrey,
         xlims=(-6,6), xticks=-6:1:6,
         ylims=(0,30), yticks=0:5:30,
         frame=:box, dpi=1000, bins=30,
         guidefont=fonts, xtickfont=fonts, ytickfont=fonts, legendfont=fonts, titlefont=font("Arial",9),
         xlabel="z-score", ylabel="Frequency")
histogram!(z_scores_abnormals, fill=pal.fl, lab="", bins=18)
plot!([-2, 2], [30, 30], fill=(0, :grey, 0.12), c=:transparent, lab="")
plot!([-2], seriestype=:vline, color=:grey, ls=:dot, lab="")
plot!([2], seriestype=:vline, color=:grey, ls=:dot, lab="")
plot!([0], seriestype=:vline, color=:grey, ls=:dot, lab="")
savefig(joinpath("figures", "z-scores"))
savefig(joinpath("figures", "submission", "fig4.pdf"))
