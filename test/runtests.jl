
using Test
using Footings
using StaticModules


@testset "TestSetField" begin 
    @info "Running Field TestSet ..."

    p = Parameter(name=:p, type=Int, description="This is a parameter.")
    t = Temporary(name=:t, type=Int, description="This is a Temporary.")
    r = Result(name=:r, type=Int, description="This is a Return.")
    @test isa(p, Parameter)
    @test isa(t, Temporary)
    @test isa(r, Result)
end

@testset "TestSetModelBase" begin 
    @info "Running Model TestSet ..."
    
    @staticmodule ns begin
        @doc "Add x and y" ->
        function func_x_y(x, y)
            return x + y
        end 
    
        @doc "Add t and z" ->
        function func_t_z(t, z)
            return t + z
        end
    end

    model1 = Model(name="Test")
    add_parameter!(model1, name=:x, type=Int, description="This is x.")
    add_parameter!(model1, name=:y, type=Int, description="This is y.")
    add_parameter!(model1, name=:z, type=Int, description="This is z.")
    add_temporary!(model1, name=:t, type=Int, description="This is t.")
    add_result!(model1, name=:r, type=Int, description="This is r.")

    add_step!(model1, ns, assign=:t, func=:func_x_y, args=(:x, :y))
    add_step!(model1, ns, assign=:z, func=:func_t_z, args=(:t, :z))

    run_test = build_runner(model1)
    @test run_test(x=1, y=2, z=3) == 6

    model2 = @model "TestMacro" ns begin
        Parameter(name=:x, type=Int, description="This is x.")
        Parameter(name=:y, type=Int, description="This is y.")
        Parameter(name=:z, type=Int, description="This is z.")
        Temporary(name=:t, type=Int, description="This is t.")
        Result(name=:r, type=Int, description="This is r.")
 
        Steps(:t=>func_x_y(x, y), :r=>func_t_z(t, z))
    end

    run_testmacro = build_runner(model2)
    @test run_testmacro(x=1, y=2, z=3) == 6
end
