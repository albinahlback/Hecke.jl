
export meataxe, charpoly, composition_factors, composition_series, submodules, maximal_submodules, minimal_submodules


####################################################################
#
#  Tools for MeatAxe
#
#####################################################################


#
# Given a matrix $M$ in echelon form and a vector, it returns
# the vector reduced with respect to $M$
#
function cleanvect(M::MatElem, v::MatElem)
  
  @assert rows(v)==1
  w=deepcopy(v)
  if iszero(v)
    return w  
  end
  for i=1:rows(M)
    ind=1
    while M[i,ind]==0
      ind+=1
    end
    if iszero(w[1,ind])
      continue
    end
    mult=w[1,ind]//M[i,ind]
    w[1,ind]=parent(M[1,1])(0)
    for k=ind+1:cols(M)
      w[1,k]-= mult*M[i,k]
    end      
  end
  return w

end

function submatrix(M::MatElem, x::UnitRange{Int}, y::UnitRange{Int})
  
  numrows=x.stop-x.start+1
  numcols=y.stop-y.start+1
  A=MatrixSpace(parent(M[1,1]), numrows, numcols)()
  for i=1:numrows
    for j=1:numcols
      A[i,j]=M[x.start+i-1, y.start+j-1]
    end
  end
  return A
  
end


#
#  Given a matrix C containing the coordinates of vectors v_1,dots, v_k 
#  in echelon form, the function computes a basis for the submodule they generate
# 

function closure(C::MatElem, G)

  rref!(C)
  i=1
  while i <= rows(C)
    w=submatrix(C, i:i, 1:cols(C))
    for j=1:length(G)
      res=cleanvect(C,w*G[j])
      if !iszero(res)
        C=vcat(C,res)  
        if rows(C)==cols(C)
          i=cols(C)+1
          break
        end
      end 
    end  
    i+=1
  end
  rref!(C)
  return C

end

#
#  Given a matrix C containing the coordinates of vectors v_1,dots, v_k,
#  the function computes a basis for the submodule they generate
# 

function spinning(C::MatElem,G)

  B=deepcopy(C)
  X=rref(C)[2]
  i=1
  while i != rows(B)+1
    for j=1:length(G)
      el=submatrix(B, i:i, 1:cols(B))*G[j]
      res= cleanvect(X,el)
      if !iszero(res)
        X=vcat(X,res)
        rref!(X)
        B=vcat(B,el)
      end
    end  
    i+=1
  end
  return B
  

end


#
#  Function to obtain the action of G on the quotient and on the submodule
#


function clean_and_quotient(M::MatElem,N::MatElem,pivotindex::Set{Int})
  
  
  coeff=MatrixSpace(parent(M[1,1]),rows(N),rows(M))()
  for i=1:rows(N)
    for j=1:rows(M)
      ind=1
      while iszero(M[j,ind])
        ind+=1
      end
      coeff[i,j]=N[i,ind]//M[j,ind]  
      for s=1:cols(N)
        N[i,s]-=coeff[i,j]*M[j,s]
      end
    end
  end 
  vec= MatrixSpace(parent(M[1,1]),rows(N),cols(M)-length(pivotindex))()
  for i=1:rows(N)  
    pos=0
    for s=1:cols(M)
      if !(s in pivotindex)
        pos+=1
        vec[i,pos]=N[i,s]
      end 
    end
  end
  return coeff, vec
end

#
#  Restriction of the action to the submodule generated by C and the quotient
#

function _split(C::MatElem,G)
# I am assuming that C is a Fp[G]-submodule

  equot=MatElem[]
  esub=MatElem[]
  pivotindex=Set{Int}()
  for i=1:rows(C)
    ind=1
    while iszero(C[i,ind])
      ind+=1
    end
    push!(pivotindex,ind)   
  end
  for a=1:length(G)
    subm,vec=clean_and_quotient(C, C*G[a],pivotindex)
    push!(esub,subm)
    s=MatrixSpace(parent(C[1,1]),cols(G[1])-length(pivotindex),cols(G[1])-length(pivotindex))()
    pos=0
    for i=1:rows(G[1])
      if !(i in pivotindex)
        m,vec=clean_and_quotient(C,submatrix(G[a],i:i,1:rows(G[1])),pivotindex)
        for j=1:cols(vec)
          s[i-pos,j]=vec[1,j]
        end
      else 
        pos+=1
      end
    end
    push!(equot,s)
  end
  return FqGModule(esub),FqGModule(equot),pivotindex

end

#
#  Restriction of the action to the submodule generated by C
#

function actsub(C::MatElem,G)

  esub=MatElem[]
  pivotindex=Set{Int}()
  for i=1:rows(C)
    ind=1
    while iszero(C[i,ind])
      ind+=1
    end
    push!(pivotindex,ind)   
  end
  for a=1:length(G)
    subm,vec=clean_and_quotient(C, C*G[a],pivotindex)
    push!(esub,subm)
  end
  return FqGModule(esub)
end

#
#  Restriction of the action to the quotient by the submodule generated by C
#

function actquo(C::MatElem,G)

  equot=MatElem[]
  pivotindex=Set{Int}()
  for i=1:rows(C)
    ind=1
    while iszero(C[i,ind])
      ind+=1
    end
    push!(pivotindex,ind)   
  end
  for a=1:length(G)
    s=MatrixSpace(parent(C[1,1]),cols(G[1])-length(pivotindex),cols(G[1])-length(pivotindex))()
    pos=0
    for i=1:rows(G[1])
      if !(i in pivotindex)
        m,vec=clean_and_quotient(C,submatrix(G[a],i:i,1:rows(G[1])),pivotindex)
        for j=1:cols(vec)
          s[i-pos,j]=vec[1,j]
        end
      else 
        pos+=1
      end
    end
    push!(equot,s)
  end
  return FqGModule(equot), pivotindex
  
end


#
#  Function that determine if two G-modules are isomorphic, provided that the first is irreducible
#

function isisomorphic(M::FqGModule,N::FqGModule)
  
  @assert M.isirreducible
  @assert M.K==N.K
  @assert length(M.G)==length(N.G)
  if M.dim!=N.dim
    return false
  end
  n=M.dim
  posfac=n
    
  K=M.K
  
  Kx,x=K["x"]
  f=Kx(1)
  G=[A for A in M.G]
  H=[A for A in N.G]
  
  #
  #  Adding generators to obtain randomness
  #
  
  for i=1:max(length(M.G),9)
    l1=rand(1:length(G))
    l2=rand(1:length(G))
    while l1 !=l2
      l2=rand(1:length(G))
    end
    push!(G, G[l1]*G[l2])
    push!(H, H[l1]*H[l2])
  end

    #
    #  Now, get the right element
    #
  
  A=MatrixSpace(K,n,n)()
  B=MatrixSpace(K,n,n)()
  found=false
  
  while !found
  
    A=MatrixSpace(K,n,n)()
    B=MatrixSpace(K,n,n)()
    l1=rand(1:length(G))
    l2=rand(1:length(G))
    push!(G, G[l1]*G[l2])
    push!(H, H[l1]*H[l2])
  
    for i=1:length(G)
      s=rand(K)
      A+=s*G[i]
      B+=s*H[i]
    end
  
    cp=charpoly(A)
    sq=factor_squarefree(cp)
    lf=factor(collect(keys(sq.fac))[1])
    for t in keys(lf.fac)
      f=t
      S=t(A)
      a,kerA=nullspace(transpose(S))
      if a==1
        M.dim_spl_fld=1
        found=true
        break
      end
      kerA=transpose(kerA)
      posfac=gcd(posfac,a)
      if divisible(fmpz(posfac),a)
        v=submatrix(kerA, 1:1, 1:n)
        U=v
        T =spinning(v,G)
        G1=[T*A*inv(T) for A in M.G]
        i=2
        E=[eye(T,a)]
        while rows(U)!= a
          w= submatrix(kerA, i:i, 1:n)
          z= cleanvect(U,w)
          if iszero(z)
            continue
          end
          O =spinning(w,G)
          G2=[O*A*inv(O) for A in N.G]
          if G1 == G2
            b=kerA*O
            x=transpose(solve(transpose(kerA),transpose(b)))
            push!(E,x)
            U=vcat(U,z)
            U=closure(U,E)
          else 
            break
          end
          if rows(U)==a
            M.dim_spl_fld=a
            found=true
            break
          else
            i+=1
          end
        end
      end
      if found==true
        break
      end
    end           
  end
    
  #
  #  Get the standard basis
  #

  
  L=f(A)
  a,kerA=nullspace(transpose(L))
  kerA=transpose(kerA)
  
  I=f(B)
  b,kerB=nullspace(transpose(I))
  kerB=transpose(kerB)

  if a!=b
    return false
  end
  
  Q= spinning(submatrix(kerA, 1:1, 1:n), M.G)
  W= spinning(submatrix(kerB, 1:1, 1:n), N.G)
  
  #
  #  Check if the actions are conjugated
  #
  S=inv(W)*Q
  T=inv(S)
  for i=1:length(M.G)
    if S*M.G[i]* T != N.G[i]
      return false
    end
  end
  return true
end


#
#  Computes peakwords for all composition factors
#


function peakwords(L)
  
  K=L[1][1].K
  i=1
  for i=1:length(L)
    if L[i][1].dim_spl_fld==0
      _spl_field(L[i][1])
    end
  end
  while i<=length(L)
    lincomb,f= peakword(L[i][1])
    if isempty(lincomb)
      i=i+1
      continue
    end
    found=true
    for j=1:i-1
      A=MatrixSpace(K,L[j][1].dim,L[j][1].dim)()
      for k=1:length(L[1][1].G)
        A+=lincomb[k]*L[j][1].G[k]
      end
      A=f(A)
      if rank(A)!=L[j][1].dim
        found=false
        break
      end
    end
    if found
      i=i+1
    end
  end
  return L

end


#
#  Computes a candidate peakword for a factor 
#

function peakword(M::FqGModule)

  @assert M.isirreducible
  n=M.dim
  K=M.K
  G=M.G
  e=M.dim_spl_fld
  lincomb=[]
  Kx,x=K["x"]
  f=Kx(1)
  A=MatrixSpace(K,n,n)()
  for i=1:100
    
    for i=1:length(G)
      push!(lincomb,rand(K))
      A+=lincomb[i]*G[i]
    end

    cp=charpoly(A)
    sq=factor_squarefree(cp)
    lf=factor(collect(keys(sq.fac))[1])
    for t in keys(lf.fac)
      f=t^2
      S=f(A)
      a=n-rank(S)
      if a==e
        M.peakword_elem=lincomb
        M.peakword_poly=f
        return lincomb, t
      end
    end        
    lincomb=[]
    A=MatrixSpace(K,n,n)()

  end
  return lincomb, Kx(0)

end


function _spl_field(M::FqGModule)
  
  @assert M.isirreducible==true
  n=M.dim
  K=M.K
  G=M.G
  posfac=n
  lincomb=[]
  Kx,x=K["x"]
  f=Kx(1)
  A=MatrixSpace(K,n,n)()
  
  while true
    
    for i=1:length(G)
      push!(lincomb,rand(K))
      A+=lincomb[i]*G[i]
    end

    cp=charpoly(A)
    sq=factor_squarefree(cp)
    lf=factor(collect(keys(sq.fac))[1])
    for t in keys(lf.fac)
      f=t
      S=t(A)
      a,kerA=nullspace(transpose(S))
      if a==1
        if divides(cp,f^2)[1]
          M.peakword_elem=lincomb
          M.peakword_poly=f
        end
        M.dim_spl_fld=1
        return lincomb, f
      end
      kerA=transpose(kerA)
      posfac=gcd(posfac,a)
      if divisible(fmpz(posfac),a)
        v=submatrix(kerA, 1:1, 1:n)
        B=v
        T =spinning(v,G)
        G1=[T*A*inv(T) for A in G]
        i=2
        E=[eye(T,a)]
        while rows(B)!= a
          w= submatrix(kerA, i:i, 1:n)
          z= cleanvect(B,w)
          if iszero(z)
            continue
          end
          N =spinning(w,G)
          G2=[N*A*inv(N) for A in G]
          if G1 == G2
            b=kerA*N
            x=transpose(solve(transpose(kerA),transpose(b)))
            push!(E,x)
            B=vcat(B,z)
            B=closure(B,E)
          else 
            break
          end
          if rows(B)==a
            if divides(cp,f^2)[1]
              M.peakword_elem=lincomb
              M.peakword_poly=f
            end
            M.dim_spl_fld=a
            return lincomb, f
          else
            i+=1
          end
        end
      end
    end        
    lincomb=[]
    A=MatrixSpace(K,n,n)()

  end
  
end



function _solve_unique(A::GenMat{fq_nmod}, B::GenMat{fq_nmod})
  X = MatrixSpace(base_ring(A), cols(B), rows(A))()

  #println("solving\n $A \n = $B * X")
  r, per, L, U = lufact(B) # P*M1 = L*U

  if oldNemo
    for i in 1:length(per.d)
      per.d[i] += 1
    end
  end

  @assert B == per*L*U
  Ap = inv(per)*A
  Y = parent(A)()

  #println("first solve\n $Ap = $L * Y")

  for i in 1:cols(Y)
    for j in 1:rows(Y)
      s = Ap[j, i]
      for k in 1:j-1
        s = s - Y[k, i]*L[j, k]
      end
      Y[j, i] = s
    end
  end

  @assert Ap == L*Y

  #println("solving \n $Y \n = $U * X")

  YY = submatrix(Y, 1:r, 1:cols(Y))
  UU = submatrix(U, 1:r, 1:r)
  X = inv(UU)*YY

  @assert Y == U * X

  @assert B*X == A
  return X
end


###############################################################
#
#  Characteristic Polynomial
#
#################################################################


function ordpoly(M::MatElem,S::MatElem,v::MatElem)

  K=parent(M[1,1])
  D=cleanvect(S,v)
  C=MatrixSpace(K, 1, cols(M)+1)()
  C[1,1]=K(1)
  if iszero(D)
    return C
  end
  ind=2
  vec=v
  while true
    vec=vec*M
    D=vcat(D, cleanvect(S,vec))
    E=MatrixSpace(K, 1, cols(M)+1)()
    E[1,ind]=K(1)
    C=vcat(C,E)
    for i=1:ind-1
      nonzero=1
      while iszero(D[i, nonzero])
        nonzero+=1
      end
      mult=D[ind,nonzero]//D[i,nonzero]
      for j=1:cols(M)+1
        C[ind,j]-=mult*C[i,j]
      end
      for j=1:cols(M)
        D[ind,j]-=mult*D[i,j]
      end
    end
    if iszero(submatrix(D, ind:ind, 1:cols(D)))
      break
    end
    ind+=1
  end
  return submatrix(C, ind:ind, 1:cols(D)+1), submatrix(D, 1:ind-1, 1:cols(D))
  
end

function charpoly_fact(M::MatElem)
  
  @assert cols(M)>0 && cols(M)==rows(M) 
  
  K=parent(M[1,1])
  polys=[]
  v=MatrixSpace(K, 1, cols(M))()
  v[1,1]=K(1)
  pol,B=ordpoly(M,MatrixSpace(K, 0, 0)(),v)
  push!(polys,pol)
  if !iszero(pol[1,cols(B)+1])
    return polys
  end
  v[1,1]=K(0)
  for i=2:cols(M)
    v[1,i]=K(1)
    red=cleanvect(B,v)
    if !iszero(red)
      x=ordpoly(M,B,red)
      push!(polys,x[1])
      B=vcat(B,x[2])
    end
    v[1,i]=K(0)
  end
  return polys
end


doc"""
***
    charpoly(M::MatElem) -> PolyElem

> Returns the characteristic polynomial of the square matrix M

"""

function charpoly(M::MatElem)
  
  @assert rows(M)>0 && rows(M)==cols(M)
  K=parent(M[1,1])
  Kx,x=K["x"]
  polys=charpoly_fact(M)
  f=Kx(1)
  for pol in polys
    coeff=[pol[1,i] for i=1:cols(pol)]
    f*=Kx(coeff)
  end
  return f
end


#################################################################
#
#  MeatAxe, Composition Factors and Composition Series
#
#################################################################



doc"""
***
    meataxe(M::FqGModule) -> Bool, MatElem

> Given module M, returns true if the module is irreducible (and the identity matrix) and false if the space is reducible, togheter with a basis of a submodule

"""

function meataxe(M::FqGModule)

  K=M.K
  Kx,x=K["x"]
  n=M.dim
  H=M.G
  if M.dim==1
    M.isirreducible=true
    return true, eye(H[1],n)
  end
  
  if length(H)==1
    A=H[1]
    poly=charpoly_fact(A)
    c=[poly[1][1,i] for i=1:cols(poly[1])]
    sq=factor_squarefree(Kx(c))
    lf=factor(collect(keys(sq.fac))[1])
    t=first(keys(lf.fac))
    if degree(t)==n
      M.isirreducible=true
      return true, eye(H[1],n)
    else 
      N=t(A)
      kern=transpose(nullspace(transpose(N))[2])
      B=closure(submatrix(kern,1:1, 1:n),H)
      return false, B
    end
  end
  
  #
  #  Adding generators to obtain randomness
  #
  G=[x for x in H]
  Gt=[transpose(x) for x in M.G]
  
  for i=1:max(length(M.G),9)
    l1=rand(1:length(G))
    l2=rand(1:length(G))
    while l1 !=l2
      l2=rand(1:length(G))
    end
    push!(G, G[l1]*G[l2])
  end
  
  
  while true
  
  # At every step, we add a generator to the group.
  
    push!(G, G[rand(1:length(G))]*G[rand(1:length(G))])
    
  #
  # Choose a random combination of the actual generators of G
  #
    A=MatrixSpace(K,n,n)()
    for i=1:length(G)
      A+=rand(K)*G[i]
    end
 
  #
  # Compute the characteristic polynomial and, for irreducible factor f, try the Norton test
  # 
    poly=charpoly_fact(A)
    for fact in poly
      c=[fact[1,i] for i=1:cols(fact)]
      sq=factor_squarefree(Kx(c))
      lf=factor(collect(keys(sq.fac))[1])
      for t in keys(lf.fac)
        N=t(A)
        a,kern=nullspace(transpose(N))
        #
        #  Norton test
        #   
        B=closure(transpose(submatrix(kern,1:n, 1:1)),M.G)
        if rows(B)!=n
          M.isirreducible=false
          return false, B
        end
        kernt=nullspace(N)[2]
        Bt=closure(transpose(submatrix(kernt,1:n,1:1)),Gt)
        if rows(Bt)!=n
          subst=transpose(nullspace(Bt)[2])
          @assert rows(subst)==rows(closure(subst,G))
          M.isirreducible=false
          return false, subst
        end
        if degree(t)==a
          #
          # f is a good factor, irreducibility!
          #
          M.isirreducible=true
          return true, eye(G[1],n)
        end
      end
    end
  end
end

doc"""
***
    composition_series(M::FqGModule) -> Array{MatElem,1}

> Given a Fq[G]-module M, it returns a composition series for M, i.e. a sequence of submodules such that the quotient of two consecutive element is irreducible.

"""

function composition_series(M::FqGModule)

  if isdefined(M, :isirreducible) && M.isirreducible==true
    return [eye(M.G[1],M.dim)]
  end

  bool, C = meataxe(M)
  #
  #  If the module is irreducible, we return a basis of the space
  #
  if bool ==true
    return [eye(M.G[1],M.dim)]
  end
  #
  #  The module is reducible, so we call the algorithm on the quotient and on the subgroup
  #
  G=M.G
  K=M.K
  
  rref!(C)
  
  esub,equot,pivotindex=_split(C,G)
  sub_list = composition_series(esub)
  quot_list = composition_series(equot)
  #
  #  Now, we have to write the submodules of the quotient and of the submodule in terms of our basis
  #
  list=MatElem[]
  for a in sub_list
    push!(list,a*C)
  end
  for a in quot_list
    s=MatrixSpace(K,rows(a), cols(C))()
    for i=1:rows(a)
      pos=0
      for j=1:cols(C)
        if j in pivotindex
          pos+=1
        else
          s[i,j]=a[i,j-pos]
        end
      end
    end
    push!(list,vcat(C,s))
  end
  return list
end

doc"""
***
    composition_factors(M::FqGModule)

> Given a Fq[G]-module M, it returns, up to isomorphism, the composition factors of M with their multiplicity,
> i.e. the isomorphism classes of modules appearing in a composition series of M

"""

function composition_factors(M::FqGModule)
  
  if isdefined(M, :isirreducible) && M.isirreducible
    return [[M,1]]
  end 
 
  K=M.K
  
  bool, C = meataxe(M)
  #
  #  If the module is irreducible, we just return a basis of the space
  #
  if bool
    return [[M,1]]
  end
  G=M.G
  #
  #  The module is reducible, so we call the algorithm on the quotient and on the subgroup
  #
  
  rref!(C)
  
  sub,quot,pivotindex=_split(C,G)
  sub_list = composition_factors(sub)
  quot_list = composition_factors(quot)
  #
  #  Now, we check if the factors are isomorphic
  #
  for i=1:length(sub_list)
    for j=1:length(quot_list)
      if isisomorphic(sub_list[i][1], quot_list[j][1])
        sub_list[i][2]+=quot_list[j][2]
        deleteat!(quot_list,j)
        break
      end    
    end
  end
  return append!(sub_list,quot_list)

end



function _relations(M::FqGModule, N::FqGModule)

  @assert M.isirreducible
  G=M.G
  H=N.G
  K=M.K
  n=M.dim
  
  sys=MatrixSpace(K,0,N.dim)()
  matrices=[]
  
  B=MatrixSpace(K,1,M.dim)()
  B[1,1]=K(1)
  X=B
  push!(matrices, eye(B,N.dim))
  i=1
  while i<=rows(B)
    w=submatrix(B, i:i, 1:n)
    for j=1:length(G)
      v=w*G[j]
      res=cleanvect(X,v)
      if !iszero(res)
        X=rref(vcat(X,v))[2]
        B=vcat(B,v)
        push!(matrices, matrices[i]*H[j])
      else
        x=_solve_unique(transpose(v),transpose(B))
        A=sum([x[q,1]*matrices[q] for q=1:rows(x)])
        A=A-(matrices[i]*H[j])
        sys=vcat(sys,transpose(A))
        rref!(sys)
        sys=submatrix(sys, 1:N.dim, 1:N.dim)
      end
    end
    i=i+1
  end
  return sys
end

function _irrsubs(M::FqGModule, N::FqGModule)

  @assert M.isirreducible
  
  K=M.K
  rel=_relations(M,N)
  a,kern=nullspace(rel)
  if a==0
    return []
  end
  kern=transpose(kern)
  if a==1
    return [closure(kern, N.G)]
  end  
  #
  #  Reduce the number of homomorphism to try by considering the action of G on the homomorphisms
  #
  vects=[submatrix(kern, i:i, 1:N.dim) for i=1:a]
  i=1
  while i<length(vects)
    X=closure(vects[i],N.G)
    j=i+1
    while j<= length(vects)
      if iszero(cleanvect(X,vects[j]))
        deleteat!(vects,j)
      else
        j+=1
      end
    end
    i+=1
  end
  if length(vects)==1
    return [closure(vects[1], N.G)]
  end
  
  #
  #  Try all the possibilities. (A recursive approach? I don't know if it is a smart idea...)
  #
  candidate_comb=append!(_enum_el(K,[K(0)], length(vects)-1),_enum_el(K,[K(1)],length(vects)-1))
  deleteat!(candidate_comb,1)
  list=[]
  for x in candidate_comb
    push!(list, sum([x[i]*vects[i] for i=1:length(vects)]))
  end
  list[1]=closure(list[1], N.G)
  i=2
  w=MatrixSpace(K,0,0)()
  while i<length(list)
    for j=1:i-1
      w=cleanvect(list[j],list[i])
      if iszero(w)
        break
      end
    end  
    if iszero(w)
      deleteat!(list,i)
    else
      list[i]=closure(list[i],N.G)
      i=i+1
    end
  end
  return list

end

doc"""
***
    minimal_submodules(M::FqGModule)

> Given a Fq[G]-module M, it returns all the minimal submodules of M

"""


function minimal_submodules(M::FqGModule, dim::Int=M.dim, lf=[])
  
  K=M.K
  n=M.dim
  
  if M.isirreducible==true
    return []
  end

  list=[]
  if isempty(lf)
    lf=composition_factors(M)
  end
  if length(lf)==1 && lf[1][2]==1
    return []
  end
  if dim!=n
    lf=[x for x in lf if x[1].dim==dim]
  end
  if isempty(lf)
    return list
  end
  G=M.G
  for x in lf
    append!(list,Hecke._irrsubs(x[1],M)) 
  end
  return list
end


function minimal_with_peakwords(M::FqGModule, index::Int=M.dim, lf=[])

  K=M.K
  n=M.dim
  
  if M.isirreducible==true
    return []
  end

  list=[]
  if isempty(lf)
    lf=composition_factors(M)
  end
  if length(lf)==1 && lf[1][2]==1
    return []
  end
  if index!=n
    lf=[x for x in lf if x[1].dim==index]
  end
  if isempty(lf)
    return list
  end
  Hecke.peakwords(lf)
  G=M.G
  for x in lf
    if isdefined(x[1],:peakword_poly)
      A=MatrixSpace(K,n,n)()
      for i=1:length(G)
        A+=x[1].peakword_elem[i]*G[i]
      end
      A=x[1].peakword_poly(A)
      a,kern=nullspace(transpose(A))
      if a==0
        continue
      end
      kern=transpose(kern)
      S=Hecke.closure(kern, G)
      if x[1].dim>rows(S)
        continue
      end
      N=Hecke.actsub(S,G)
      if N.dim == x[1].dim
        if isisomorphic(x[1],N)
          push!(list, S)
        end
        continue
      end 
      H=Hecke._irrsubs(x[1],N)
      for a in H
        push!(list,a*S)
      end
    else 
      append!(list,Hecke._irrsubs(x[1],M))
    end   
  end
  return list

end


function _enum_el(K,v,dim)
  
  if dim == 0
    return [v]
  else 
    list=[]
    push!(v,K(0))
    for x in K 
      v[length(v)]=x
      push!(list,deepcopy(v))
    end
    list1=[]
    for x in list
      append!(list1,_enum_el(K,x, dim-1))
    end
    return list1
  end
end

doc"""
***
    maximal_submodules(M::FqGModule)

> Given a $G$-module $M$, it returns all the maximal submodules of M

"""

function maximal_submodules(M::FqGModule, index::Int=M.dim, lf=[])


  G=[transpose(A) for A in M.G]
  M_dual=FqGModule(G)
  minlist=minimal_submodules(M_dual, index, lf)
  maxlist=[]
  for x in minlist
    push!(maxlist,transpose(nullspace(x)[2]))
  end
  return maxlist

end

doc"""
***
    submodules(M::FqGModule)

> Given a $G$-module $M$, it returns all the submodules of M

"""

function submodules(M::FqGModule)

  K=M.K
  list=[]
  lf=composition_factors(M)
  minlist=minimal_submodules(M, M.dim, lf)
  for x in minlist
    rref!(x)
    N, pivotindex =actquo(x,M.G)
    ls=submodules(N)
    for a in ls
      s=MatrixSpace(K,rows(a), M.dim)()
      for t=1:rows(a)
        pos=0
        for j=1:M.dim
          if j in pivotindex
            pos+=1
          else
            s[t,j]=a[t,j-pos]
          end
        end
      end
      push!(list,vcat(x,s))
    end
  end
  for x in list
    rref!(x)
  end
  i=2
  while i<length(list)
    j=i+1
    while j<=length(list)
      if rows(list[j])!=rows(list[i])
        j+=1
      else
        if iszero(list[j]-list[i])
          deleteat!(list, j)
        else 
          j+=1
        end
      end
    end
    i+=1
  end
  return append!(list,minlist)
  
end

doc"""
***
    submodules(M::FqGModule, index::Int)

> Given a $G$-module $M$, it returns all the submodules of M of index q^index, where q is the order of the field

"""

function submodules(M::FqGModule, index::Int)
  
  K=M.K
  if index==M.dim
    return [MatrixSpace(K,1,M.dim)()]
  end
  list=[]
  if index>= M.dim/2
    lf=composition_factors(M)
    for i=1: M.dim-index-1
      minlist=minimal_submodules(M,i,lf)
      for x in minlist
        N, pivotindex= actquo(x, M.G)
        ls=submodules(N,index)
        for a in ls
          s=MatrixSpace(K,rows(a), M.dim)()
          for t=1:rows(a)
            pos=0
            for j=1:M.dim
              if j in pivotindex
               pos+=1
             else
               s[t,j]=a[t,j-pos]
              end
           end
          end
          push!(list,vcat(x,s))
        end
      end
    end
  #
  #  Redundance!
  #
    for x in list
      rref!(x)
    end
    i=1
    while i<length(list)
      j=i+1
      while j<=length(list)
        if iszero(list[j]-list[i])
          deleteat!(list, j)
        else 
          j+=1
        end
      end
      i+=1
    end
    append!(list,minimal_submodules(M,M.dim-index, lf))
  else 
  #
  #  Duality
  # 
    G=[transpose(A) for A in M.G]
    M_dual=FqGModule(G)
    dlist=submodules(M_dual, M.dim-index)
    list=[transpose(nullspace(x)[2]) for x in dlist]
  end

  
  return list
    
end
    
