addprocs(3)

@everywhere begin

function myMatVec{T<:Real}(A::Array{T,2},x::Vector{T})::Vector{T}
  m,n = size(A)
#   if length(x) != n
#     error("Incompatible dimensions")
#   end
  
  b = zeros(m)
  for j = 1:n
    b += x[j]*view(A,:,j)
  end
  return b
end


function myMatVecParallelDefault{T<:Real}(A::Array{T,2},x::Vector{T})::Vector{T}
  m,n = size(A)
  if length(x) != n
    error("Incompatible dimensions")
  end
  
  b = @parallel (+) for j = 1:n
    c = x[j]*view(A,:,j)
  end
end


function myMatVecParallelCustom{T<:Real}(A::Array{T,2},x::Vector{T})::Vector{T}

  m,n = size(A)
  if length(x) != n
    error("Incompatible dimensions")
  end
  
  # Figure out if there's a way of adding contribution from each worker to total as it comes in,
  # rather than saving them all and doing the sum locally.
  
  #Figure out chunk size
  workerList = workers()
  nworkers   = length(workerList)
  chunkSize  = div(n,nworkers)
  chunks = Vector{Range}(nworkers)
  for i = 1:max(nworkers-1,1)
    chunks[i] = ((i-1)*chunkSize + 1):(i*chunkSize)
  end
  chunks[nworkers] = ((nworkers-1)*chunkSize + 1):n
  
  #Do the work
  c = zeros(m,nworkers)
  @sync begin
    for p in workerList
      @async begin
        c[:,p-1] = remotecall_fetch(myMatVec,p,A[:,chunks[p-1]],x[chunks[p-1]])
      end
    end
  end
  return vec(sum(c,2))
end


function myMatVec(Aref::Future,xref::Future)
  Aloc = fetch(Aref)
  xloc = fetch(xref)
  return myMatVec(Aloc,xloc)
end

#---------------------------------------------------------------------------

function myMatVecNoCommunication(Arefs::Array{Future},xrefs::Array{Future},m,n)::Vector{Real}

#   m,n = size(A)
#   if length(x) != n
#     error("Incompatible dimensions")
#   end

  workerList = workers()
  nworkers = length(workerList)
  
  #Do the work
  c      = zeros(m)
  #tmpVec = zeros(m)
  @sync begin
    for p in workerList
      @async begin
        tmpVec = remotecall_fetch(myMatVec,p,Arefs[p-1],xrefs[p-1])
        c      += tmpVec
      end
    end
  end
  return c
end

function myMatVecNoCommunicationTask(Arefs::Array{Future},xrefs::Array{Future},m,n)::Vector{Real}

#   m,n = size(A)
#   if length(x) != n
#     error("Incompatible dimensions")
#   end

  workerList = workers()
  nworkers = length(workerList)
  
  #Do the work
  c      = zeros(m)
  #tmpVec = zeros(m)
  @sync begin
    for p in workerList
      t = @task begin
        tmpVec = remotecall_fetch(myMatVec,p,Arefs[p-1],xrefs[p-1])
        c      += tmpVec
      end
      Base.sync_add(t)
      Base.enq_work(t)
    end
  end
  return c
end

end #end @everywhere block


n = 21000
A = randn(n,n)
x = randn(n)

Arfs = Array{Future}(3)
xrfs = Array{Future}(3)

for i = 2:4
  Arfs[i-1] = @spawnat i A[:,(i-2)*7000+1:(i-1)*7000]
  xrfs[i-1] = @spawnat i x[(i-2)*7000+1:(i-1)*7000]
end


