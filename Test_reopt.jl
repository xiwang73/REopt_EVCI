using REopt, JuMP,Cbc, CSV
using JSON
ENV["NREL_DEVELOPER_API_KEY"]="u6YmC0rQPUZx454CrUggWweituJqRXMnJEIIfHzQ"

# m = Model(Cbc.Optimizer)
# results = run_reopt(m, "test/scenarios/pv_storage.json")
m = Model(Cbc.Optimizer)
results = run_reopt(m, "C:/Devesh_Georgia_Tech/New folder/REopt_EVCI/test/scenarios/pv_storage.json")
# CSV.write("C:\\Devesh_Georgia_Tech\\New folder\\Terra_REopt_24\\test_10.csv", results)
# CSV.write("C:\\Users\\dmurugesan3\\Documents\\Github\\REopt.jl\\test_1.csv", results)
resdata = JSON.json(results)

open("C:\\Devesh_Georgia_Tech\\New folder\\REopt_EVCI\\case_X_res.json", "w") do f
    write(f, resdata)
end


