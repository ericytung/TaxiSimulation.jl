###################################################
## online/insertonly.jl
## online algorithm that just performs insertions
###################################################

"""
	`InsertOnly`, OnlineAlgorithm that just performs insertions in taxis timelines
"""
type InsertOnly <: OnlineAlgorithm
	pb::TaxiProblem
	sol::OfflineSolution
    startTime::Float64
	earliest::Bool

    function InsertOnly(;earliest::Bool=false)
        io = new()
		io.earliest = earliest
        return io
    end
end

function onlineInitialize!(io::InsertOnly, pb::TaxiProblem)
	pb.taxis = copy(pb.taxis)
    io.pb = pb
	io.startTime=0.

	newCustomers = pb.custs
	io.pb.custs = Customer[]
	io.sol = OfflineSolution(pb)
	if !isempty(newCustomers)
		resize!(io.pb.custs, maximum([c.id for c in newCustomers]))
	end
	for c in newCustomers
		push!(io.sol.rejected, c.id)
		io.pb.custs[c.id] = c
    end
	orderedInsertions!(io.sol)
end


function onlineUpdate!(io::InsertOnly, endTime::Float64, newCustomers::Vector{Customer})
    pb = io.pb
	tt = getPathTimes(pb.times)
	#Insert new customers
    for c in sort!(newCustomers, by=x->x.tmin)
        if length(pb.custs) < c.id
            resize!(pb.custs, c.id)
        end
        if c.tmax >= io.startTime
			push!(io.sol.rejected, c.id)
            pb.custs[c.id] = c
            insertCustomer!(io.sol,c.id, earliest=io.earliest)
        end
    end
    actions = emptyActions(pb)

	#Apply next actions
    for (k,custs) in enumerate(io.sol.custs)
        while !isempty(custs)
            c = custs[1]
            if c.tInf - tt[pb.taxis[k].initPos, pb.custs[c.id].orig] <= endTime
				path, times = getPathWithTimes(pb.times, pb.taxis[k].initPos, pb.custs[c.id].orig,
									startTime=c.tInf - tt[pb.taxis[k].initPos, pb.custs[c.id].orig])
				append!(actions[k].path, path[2:end])
				append!(actions[k].times, times)
				path, times = getPathWithTimes(pb.times, pb.custs[c.id].orig, pb.custs[c.id].dest,
								 	startTime=c.tInf + pb.customerTime)
				append!(actions[k].path, path[2:end])
				append!(actions[k].times, times)

                newTime = c.tInf + 2*pb.customerTime + tt[pb.custs[c.id].orig, pb.custs[c.id].dest]
                push!(actions[k].custs, CustomerAssignment(c.id, c.tInf, newTime))
                pb.taxis[k] = Taxi(pb.taxis[k].id, pb.custs[c.id].dest, newTime)
                shift!(custs)
            else
                break
            end
        end
		if pb.taxis[k].initTime < endTime
			pb.taxis[k] = Taxi(pb.taxis[k].id, pb.taxis[k].initPos, endTime)
		end
    end
    io.startTime = endTime

	return actions
end
