import java.text.NumberFormat;
import java.text.DecimalFormat;
import java.text.DecimalFormatSymbols;


/**
 NOTE (msoula): algo is inspired from scikit-image's source code
                https://github.com/scikit-image/scikit-image/blob/master/skimage/transform/_geometric.py#L590
 */

class ProjectiveTransform {
  
  final Matrix _txMatrix;
  
  public ProjectiveTransform(vec2f[] src, vec2f[] dst) {
    if (4 != src.length || 4 != dst.length) { //<>// //<>// //<>// //<>//
      println("Error: getTransformMatrix input length is not 4");
      _txMatrix = null;
    } else {
      _txMatrix = getTransformMatrix(src, dst);
    }
  }
  
  public vec2f transform(vec2f coords) {
    
    if (null == _txMatrix) {
      // return invalid coords
      return new vec2f(-1., -1);
    }
    
    final Matrix src = new Matrix(3,1);
    Matrix dst;
        
    src.set(0, 0, coords.x);
    src.set(1, 0, coords.y);
    src.set(2, 0, 1.);
    dst = src.transpose().times(_txMatrix.transpose());
       
    // rescale to homogeneous coordinates
    dst.set(0, 0, dst.get(0, 0) / dst.get(0, 2));
    dst.set(0, 1, dst.get(0, 1) / dst.get(0, 2));
    
    return new vec2f((float) dst.get(0, 0), (float) dst.get(0, 1));
  }
  
  private Matrix getNormalizeMatrix(vec2f[] points) {
  
    float[] centroid = new float[] {(points[0].x + points[1].x + points[2].x + points[3].x) / 4., (points[0].y + points[1].y + points[2].y + points[3].y) / 4.};
      
    float[][] tmp = new float[][] {
      {(points[0].x-centroid[0])*(points[0].x-centroid[0]), (points[0].y-centroid[1])*(points[0].y-centroid[1])}, 
      {(points[1].x-centroid[0])*(points[1].x-centroid[0]), (points[1].y-centroid[1])*(points[1].y-centroid[1])}, 
      {(points[2].x-centroid[0])*(points[2].x-centroid[0]), (points[2].y-centroid[1])*(points[2].y-centroid[1])}, 
      {(points[3].x-centroid[0])*(points[3].x-centroid[0]), (points[3].y-centroid[1])*(points[3].y-centroid[1])},
    };    
    double rms = Math.sqrt((tmp[0][0] + tmp[0][1] + tmp[1][0] + tmp[1][1] + tmp[2][0] + tmp[2][1] + tmp[3][0] + tmp[3][1])/4.);
    double normFactor = Math.sqrt(2) / rms;
  
    return new Matrix(new double[][] {
      {normFactor, 0, -normFactor*centroid[0]}, 
      {0, normFactor, -normFactor*centroid[1]}, 
      {0, 0, 1}
    });
  }
  
  private Matrix getNormalizedPoints(vec2f[] points, Matrix matrix) {
  
    Matrix pointsh = new Matrix(new double[][] {
      {points[0].x, points[1].x, points[2].x, points[3].x}, 
      {points[0].y, points[1].y, points[2].y, points[3].y}, 
      {1., 1., 1., 1.}
    });
  
    return matrix.times(pointsh).transpose().getMatrix(new int[]{0,1,2,3}, 0, 1);
  }
  
  private Matrix getTransformMatrix(final vec2f[] src, final vec2f[] dst) {
    
    /**
     center and normalize points
    */
    Matrix srcMatrix = getNormalizeMatrix(src);
    Matrix dstMatrix = getNormalizeMatrix(dst);
    Matrix srcNorm = getNormalizedPoints(src, srcMatrix);
    Matrix dstNorm = getNormalizedPoints(dst, dstMatrix);
       
    /**
     main stuff:
     xs = srcNorm[:, 0]
     ys = srcNorm[:, 1]
     xd = dstNorm[:, 0]
     yd = dstNorm[:, 1]
    */
    double[] xs = new double[] {srcNorm.get(0, 0), srcNorm.get(1, 0), srcNorm.get(2, 0), srcNorm.get(3, 0)};
    double[] ys = new double[] {srcNorm.get(0, 1), srcNorm.get(1, 1), srcNorm.get(2, 1), srcNorm.get(3, 1)};
    double[] xd = new double[] {dstNorm.get(0, 0), dstNorm.get(1, 0), dstNorm.get(2, 0), dstNorm.get(3, 0)};
    double[] yd = new double[] {dstNorm.get(0, 1), dstNorm.get(1, 1), dstNorm.get(2, 1), dstNorm.get(3, 1)};
    
    // params: a0, a1, a2, b0, b1, b2, c0, c1
    Matrix A = new Matrix(new double[][] {
      {xs[0], ys[0], 1, 0, 0, 0, -xd[0]*xs[0], -xd[0]*ys[0], xd[0]},
      {xs[1], ys[1], 1, 0, 0, 0, -xd[1]*xs[1], -xd[1]*ys[1], xd[1]},
      {xs[2], ys[2], 1, 0, 0, 0, -xd[2]*xs[2], -xd[2]*ys[2], xd[2]},
      {xs[3], ys[3], 1, 0, 0, 0, -xd[3]*xs[3], -xd[3]*ys[3], xd[3]},
      {0, 0, 0, xs[0], ys[0], 1, -yd[0]*xs[0], -yd[0]*ys[0], yd[0]},
      {0, 0, 0, xs[1], ys[1], 1, -yd[1]*xs[1], -yd[1]*ys[1], yd[1]},
      {0, 0, 0, xs[2], ys[2], 1, -yd[2]*xs[2], -yd[2]*ys[2], yd[2]},
      {0, 0, 0, xs[3], ys[3], 1, -yd[3]*xs[3], -yd[3]*ys[3], yd[3]},
      {0f, 0f, 0f, 0f, 0f, 0f, 0f, 0f, 0f} // need a mxm matrix here      
    });
    
    // svd  
    Matrix V = A.svd().getV().transpose();
   
    // solution is right singular vector that corresponds to smallest
    // singular value
    Matrix H = new Matrix(3, 3);
    H.set(0, 0, -V.get(8, 0) / V.get(8, 8));
    H.set(0, 1, -V.get(8, 1) / V.get(8, 8));
    H.set(0, 2, -V.get(8, 2) / V.get(8, 8));
    H.set(1, 0, -V.get(8, 3) / V.get(8, 8));
    H.set(1, 1, -V.get(8, 4) / V.get(8, 8));
    H.set(1, 2, -V.get(8, 5) / V.get(8, 8));
    H.set(2, 0, -V.get(8, 6) / V.get(8, 8));
    H.set(2, 1, -V.get(8, 7) / V.get(8, 8));
    H.set(2, 2, 1);
    
    // De-center and de-normalize
    Matrix transform = dstMatrix.inverse().times(H).times(srcMatrix);
    
    return transform;
  }
}

/**
 NOTE (msoula): code below is extracted from JAMA fork source code
 https://github.com/fiji/Jama
 */

class Maths {

  /** sqrt(a^2 + b^2) without under/overflow. **/

  public double hypot(double a, double b) {
    double r;
    if (Math.abs(a) > Math.abs(b)) {
      r = b/a;
      r = Math.abs(a)*Math.sqrt(1+r*r);
    } else if (b != 0) {
      r = a/b;
      r = Math.abs(b)*Math.sqrt(1+r*r);
    } else {
      r = 0.0;
    }
    return r;
  }
}

/** Singular Value Decomposition.
 <P>
 For an m-by-n matrix A with m >= n, the singular value decomposition is
 an m-by-n orthogonal matrix U, an n-by-n diagonal matrix S, and
 an n-by-n orthogonal matrix V so that A = U*S*V'.
 <P>
 The singular values, sigma[k] = S[k][k], are ordered so that
 sigma[0] >= sigma[1] >= ... >= sigma[n-1].
 <P>
 The singular value decompostion always exists, so the constructor will
 never fail.  The matrix condition number and the effective numerical
 rank can be computed from this decomposition.
 */
class SingularValueDecomposition {

  /* ------------------------
   Class variables
   * ------------------------ */

  /** Arrays for internal storage of U and V.
   @serial internal storage of U.
   @serial internal storage of V.
   */
  private double[][] U, V;

  /** Array for internal storage of singular values.
   @serial internal storage of singular values.
   */
  private double[] s;

  /** Row and column dimensions.
   @serial row dimension.
   @serial column dimension.
   */
  private int m, n;

  /* ------------------------
   Constructor
   * ------------------------ */

  /** Construct the singular value decomposition
   @param A    Rectangular matrix
   @return     Structure to access U, S and V.
   */

  public SingularValueDecomposition (Matrix Arg) {

    // Derived from LINPACK code.
    // Initialize.
    double[][] A = Arg.getArrayCopy();
    m = Arg.getRowDimension();
    n = Arg.getColumnDimension();

    /* Apparently the failing cases are only a proper subset of (m<n), 
     so let's not throw error.  Correct fix to come later?
     if (m<n) {
     throw new IllegalArgumentException("Jama SVD only works for m >= n"); }
     */
    int nu = Math.min(m, n);
    s = new double [Math.min(m+1, n)];
    U = new double [m][nu];
    V = new double [n][n];
    double[] e = new double [n];
    double[] work = new double [m];
    boolean wantu = true;
    boolean wantv = true;

    // Reduce A to bidiagonal form, storing the diagonal elements
    // in s and the super-diagonal elements in e.

    int nct = Math.min(m-1, n);
    int nrt = Math.max(0, Math.min(n-2, m));
    for (int k = 0; k < Math.max(nct, nrt); k++) {
      if (k < nct) {

        // Compute the transformation for the k-th column and
        // place the k-th diagonal in s[k].
        // Compute 2-norm of k-th column without under/overflow.
        s[k] = 0;
        for (int i = k; i < m; i++) {
          s[k] = new Maths().hypot(s[k], A[i][k]);
        }
        if (s[k] != 0.0) {
          if (A[k][k] < 0.0) {
            s[k] = -s[k];
          }
          for (int i = k; i < m; i++) {
            A[i][k] /= s[k];
          }
          A[k][k] += 1.0;
        }
        s[k] = -s[k];
      }
      for (int j = k+1; j < n; j++) {
        if ((k < nct) && (s[k] != 0.0)) {

          // Apply the transformation.

          double t = 0;
          for (int i = k; i < m; i++) {
            t += A[i][k]*A[i][j];
          }
          t = -t/A[k][k];
          for (int i = k; i < m; i++) {
            A[i][j] += t*A[i][k];
          }
        }

        // Place the k-th row of A into e for the
        // subsequent calculation of the row transformation.

        e[j] = A[k][j];
      }
      if (wantu && (k < nct)) {

        // Place the transformation in U for subsequent back
        // multiplication.

        for (int i = k; i < m; i++) {
          U[i][k] = A[i][k];
        }
      }
      if (k < nrt) {

        // Compute the k-th row transformation and place the
        // k-th super-diagonal in e[k].
        // Compute 2-norm without under/overflow.
        e[k] = 0;
        for (int i = k+1; i < n; i++) {
          e[k] = new Maths().hypot(e[k], e[i]);
        }
        if (e[k] != 0.0) {
          if (e[k+1] < 0.0) {
            e[k] = -e[k];
          }
          for (int i = k+1; i < n; i++) {
            e[i] /= e[k];
          }
          e[k+1] += 1.0;
        }
        e[k] = -e[k];
        if ((k+1 < m) && (e[k] != 0.0)) {

          // Apply the transformation.

          for (int i = k+1; i < m; i++) {
            work[i] = 0.0;
          }
          for (int j = k+1; j < n; j++) {
            for (int i = k+1; i < m; i++) {
              work[i] += e[j]*A[i][j];
            }
          }
          for (int j = k+1; j < n; j++) {
            double t = -e[j]/e[k+1];
            for (int i = k+1; i < m; i++) {
              A[i][j] += t*work[i];
            }
          }
        }
        if (wantv) {

          // Place the transformation in V for subsequent
          // back multiplication.

          for (int i = k+1; i < n; i++) {
            V[i][k] = e[i];
          }
        }
      }
    }

    // Set up the final bidiagonal matrix or order p.

    int p = Math.min(n, m+1);
    if (nct < n) {
      s[nct] = A[nct][nct];
    }
    if (m < p) {
      s[p-1] = 0.0;
    }
    if (nrt+1 < p) {
      e[nrt] = A[nrt][p-1];
    }
    e[p-1] = 0.0;

    // If required, generate U.

    if (wantu) {
      for (int j = nct; j < nu; j++) {
        for (int i = 0; i < m; i++) {
          U[i][j] = 0.0;
        }
        U[j][j] = 1.0;
      }
      for (int k = nct-1; k >= 0; k--) {
        if (s[k] != 0.0) {
          for (int j = k+1; j < nu; j++) {
            double t = 0;
            for (int i = k; i < m; i++) {
              t += U[i][k]*U[i][j];
            }
            t = -t/U[k][k];
            for (int i = k; i < m; i++) {
              U[i][j] += t*U[i][k];
            }
          }
          for (int i = k; i < m; i++ ) {
            U[i][k] = -U[i][k];
          }
          U[k][k] = 1.0 + U[k][k];
          for (int i = 0; i < k-1; i++) {
            U[i][k] = 0.0;
          }
        } else {
          for (int i = 0; i < m; i++) {
            U[i][k] = 0.0;
          }
          U[k][k] = 1.0;
        }
      }
    }

    // If required, generate V.

    if (wantv) {
      for (int k = n-1; k >= 0; k--) {
        if ((k < nrt) && (e[k] != 0.0)) {
          for (int j = k+1; j < nu; j++) {
            double t = 0;
            for (int i = k+1; i < n; i++) {
              t += V[i][k]*V[i][j];
            }
            t = -t/V[k+1][k];
            for (int i = k+1; i < n; i++) {
              V[i][j] += t*V[i][k];
            }
          }
        }
        for (int i = 0; i < n; i++) {
          V[i][k] = 0.0;
        }
        V[k][k] = 1.0;
      }
    }

    // Main iteration loop for the singular values.

    int pp = p-1;
    int iter = 0;
    double eps = Math.pow(2.0, -52.0);
    double tiny = Math.pow(2.0, -966.0);
    while (p > 0) {
      int k, kase;

      // Here is where a test for too many iterations would go.

      // This section of the program inspects for
      // negligible elements in the s and e arrays.  On
      // completion the variables kase and k are set as follows.

      // kase = 1     if s(p) and e[k-1] are negligible and k<p
      // kase = 2     if s(k) is negligible and k<p
      // kase = 3     if e[k-1] is negligible, k<p, and
      //              s(k), ..., s(p) are not negligible (qr step).
      // kase = 4     if e(p-1) is negligible (convergence).

      for (k = p-2; k >= -1; k--) {
        if (k == -1) {
          break;
        }
        if (Math.abs(e[k]) <=
          tiny + eps*(Math.abs(s[k]) + Math.abs(s[k+1]))) {
          e[k] = 0.0;
          break;
        }
      }
      if (k == p-2) {
        kase = 4;
      } else {
        int ks;
        for (ks = p-1; ks >= k; ks--) {
          if (ks == k) {
            break;
          }
          double t = (ks != p ? Math.abs(e[ks]) : 0.) + 
            (ks != k+1 ? Math.abs(e[ks-1]) : 0.);
          if (Math.abs(s[ks]) <= tiny + eps*t) {
            s[ks] = 0.0;
            break;
          }
        }
        if (ks == k) {
          kase = 3;
        } else if (ks == p-1) {
          kase = 1;
        } else {
          kase = 2;
          k = ks;
        }
      }
      k++;

      // Perform the task indicated by kase.

      switch (kase) {

        // Deflate negligible s(p).

      case 1: 
        {
          double f = e[p-2];
          e[p-2] = 0.0;
          for (int j = p-2; j >= k; j--) {
            double t = new Maths().hypot(s[j], f);
            double cs = s[j]/t;
            double sn = f/t;
            s[j] = t;
            if (j != k) {
              f = -sn*e[j-1];
              e[j-1] = cs*e[j-1];
            }
            if (wantv) {
              for (int i = 0; i < n; i++) {
                t = cs*V[i][j] + sn*V[i][p-1];
                V[i][p-1] = -sn*V[i][j] + cs*V[i][p-1];
                V[i][j] = t;
              }
            }
          }
        }
        break;

        // Split at negligible s(k).

      case 2: 
        {
          double f = e[k-1];
          e[k-1] = 0.0;
          for (int j = k; j < p; j++) {
            double t = new Maths().hypot(s[j], f);
            double cs = s[j]/t;
            double sn = f/t;
            s[j] = t;
            f = -sn*e[j];
            e[j] = cs*e[j];
            if (wantu) {
              for (int i = 0; i < m; i++) {
                t = cs*U[i][j] + sn*U[i][k-1];
                U[i][k-1] = -sn*U[i][j] + cs*U[i][k-1];
                U[i][j] = t;
              }
            }
          }
        }
        break;

        // Perform one qr step.

      case 3: 
        {

          // Calculate the shift.

          double scale = Math.max(Math.max(Math.max(Math.max(
            Math.abs(s[p-1]), Math.abs(s[p-2])), Math.abs(e[p-2])), 
            Math.abs(s[k])), Math.abs(e[k]));
          double sp = s[p-1]/scale;
          double spm1 = s[p-2]/scale;
          double epm1 = e[p-2]/scale;
          double sk = s[k]/scale;
          double ek = e[k]/scale;
          double b = ((spm1 + sp)*(spm1 - sp) + epm1*epm1)/2.0;
          double c = (sp*epm1)*(sp*epm1);
          double shift = 0.0;
          if ((b != 0.0) | (c != 0.0)) {
            shift = Math.sqrt(b*b + c);
            if (b < 0.0) {
              shift = -shift;
            }
            shift = c/(b + shift);
          }
          double f = (sk + sp)*(sk - sp) + shift;
          double g = sk*ek;

          // Chase zeros.

          for (int j = k; j < p-1; j++) {
            double t = new Maths().hypot(f, g);
            double cs = f/t;
            double sn = g/t;
            if (j != k) {
              e[j-1] = t;
            }
            f = cs*s[j] + sn*e[j];
            e[j] = cs*e[j] - sn*s[j];
            g = sn*s[j+1];
            s[j+1] = cs*s[j+1];
            if (wantv) {
              for (int i = 0; i < n; i++) {
                t = cs*V[i][j] + sn*V[i][j+1];
                V[i][j+1] = -sn*V[i][j] + cs*V[i][j+1];
                V[i][j] = t;
              }
            }
            t = new Maths().hypot(f, g);
            cs = f/t;
            sn = g/t;
            s[j] = t;
            f = cs*e[j] + sn*s[j+1];
            s[j+1] = -sn*e[j] + cs*s[j+1];
            g = sn*e[j+1];
            e[j+1] = cs*e[j+1];
            if (wantu && (j < m-1)) {
              for (int i = 0; i < m; i++) {
                t = cs*U[i][j] + sn*U[i][j+1];
                U[i][j+1] = -sn*U[i][j] + cs*U[i][j+1];
                U[i][j] = t;
              }
            }
          }
          e[p-2] = f;
          iter = iter + 1;
        }
        break;

        // Convergence.

      case 4: 
        {

          // Make the singular values positive.

          if (s[k] <= 0.0) {
            s[k] = (s[k] < 0.0 ? -s[k] : 0.0);
            if (wantv) {
              for (int i = 0; i <= pp; i++) {
                V[i][k] = -V[i][k];
              }
            }
          }

          // Order the singular values.

          while (k < pp) {
            if (s[k] >= s[k+1]) {
              break;
            }
            double t = s[k];
            s[k] = s[k+1];
            s[k+1] = t;
            if (wantv && (k < n-1)) {
              for (int i = 0; i < n; i++) {
                t = V[i][k+1]; 
                V[i][k+1] = V[i][k]; 
                V[i][k] = t;
              }
            }
            if (wantu && (k < m-1)) {
              for (int i = 0; i < m; i++) {
                t = U[i][k+1]; 
                U[i][k+1] = U[i][k]; 
                U[i][k] = t;
              }
            }
            k++;
          }
          iter = 0;
          p--;
        }
        break;
      }
    }
  }

  /* ------------------------
   Public Methods
   * ------------------------ */

  /** Return the left singular vectors
   @return     U
   */

  public Matrix getU () {
    return new Matrix(U, m, Math.min(m+1, n));
  }

  /** Return the right singular vectors
   @return     V
   */

  public Matrix getV () {
    return new Matrix(V, n, n);
  }

  /** Return the one-dimensional array of singular values
   @return     diagonal of S.
   */

  public double[] getSingularValues () {
    return s;
  }

  /** Return the diagonal matrix of singular values
   @return     S
   */

  public Matrix getS () {
    Matrix X = new Matrix(n, n);
    double[][] S = X.getArray();
    for (int i = 0; i < n; i++) {
      for (int j = 0; j < n; j++) {
        S[i][j] = 0.0;
      }
      S[i][i] = this.s[i];
    }
    return X;
  }

  /** Two norm
   @return     max(S)
   */

  public double norm2 () {
    return s[0];
  }

  /** Two norm condition number
   @return     max(S)/min(S)
   */

  public double cond () {
    return s[0]/s[Math.min(m, n)-1];
  }

  /** Effective numerical matrix rank
   @return     Number of nonnegligible singular values.
   */

  public int rank () {
    double eps = Math.pow(2.0, -52.0);
    double tol = Math.max(m, n)*s[0]*eps;
    int r = 0;
    for (int i = 0; i < s.length; i++) {
      if (s[i] > tol) {
        r++;
      }
    }
    return r;
  }
}

class LUDecomposition implements java.io.Serializable {

  /* ------------------------
   Class variables
   * ------------------------ */

  /** Array for internal storage of decomposition.
   @serial internal array storage.
   */
  private double[][] LU;

  /** Row and column dimensions, and pivot sign.
   @serial column dimension.
   @serial row dimension.
   @serial pivot sign.
   */
  private int m, n, pivsign; 

  /** Internal storage of pivot vector.
   @serial pivot vector.
   */
  private int[] piv;

  /* ------------------------
   Constructor
   * ------------------------ */

  /** LU Decomposition
   @param  A   Rectangular matrix
   @return     Structure to access L, U and piv.
   */

  public LUDecomposition (Matrix A) {

    // Use a "left-looking", dot-product, Crout/Doolittle algorithm.

    LU = A.getArrayCopy();
    m = A.getRowDimension();
    n = A.getColumnDimension();
    piv = new int[m];
    for (int i = 0; i < m; i++) {
      piv[i] = i;
    }
    pivsign = 1;
    double[] LUrowi;
    double[] LUcolj = new double[m];

    // Outer loop.

    for (int j = 0; j < n; j++) {

      // Make a copy of the j-th column to localize references.

      for (int i = 0; i < m; i++) {
        LUcolj[i] = LU[i][j];
      }

      // Apply previous transformations.

      for (int i = 0; i < m; i++) {
        LUrowi = LU[i];

        // Most of the time is spent in the following dot product.

        int kmax = Math.min(i, j);
        double s = 0.0;
        for (int k = 0; k < kmax; k++) {
          s += LUrowi[k]*LUcolj[k];
        }

        LUrowi[j] = LUcolj[i] -= s;
      }

      // Find pivot and exchange if necessary.

      int p = j;
      for (int i = j+1; i < m; i++) {
        if (Math.abs(LUcolj[i]) > Math.abs(LUcolj[p])) {
          p = i;
        }
      }
      if (p != j) {
        for (int k = 0; k < n; k++) {
          double t = LU[p][k]; 
          LU[p][k] = LU[j][k]; 
          LU[j][k] = t;
        }
        int k = piv[p]; 
        piv[p] = piv[j]; 
        piv[j] = k;
        pivsign = -pivsign;
      }

      // Compute multipliers.

      if (j < m & LU[j][j] != 0.0) {
        for (int i = j+1; i < m; i++) {
          LU[i][j] /= LU[j][j];
        }
      }
    }
  }

  /* ------------------------
   Temporary, experimental code.
   ------------------------ *\
   
   \** LU Decomposition, computed by Gaussian elimination.
   <P>
   This constructor computes L and U with the "daxpy"-based elimination
   algorithm used in LINPACK and MATLAB.  In Java, we suspect the dot-product,
   Crout algorithm will be faster.  We have temporarily included this
   constructor until timing experiments confirm this suspicion.
   <P>
   @param  A             Rectangular matrix
   @param  linpackflag   Use Gaussian elimination.  Actual value ignored.
   @return               Structure to access L, U and piv.
   *\
   
   public LUDecomposition (Matrix A, int linpackflag) {
   // Initialize.
   LU = A.getArrayCopy();
   m = A.getRowDimension();
   n = A.getColumnDimension();
   piv = new int[m];
   for (int i = 0; i < m; i++) {
   piv[i] = i;
   }
   pivsign = 1;
   // Main loop.
   for (int k = 0; k < n; k++) {
   // Find pivot.
   int p = k;
   for (int i = k+1; i < m; i++) {
   if (Math.abs(LU[i][k]) > Math.abs(LU[p][k])) {
   p = i;
   }
   }
   // Exchange if necessary.
   if (p != k) {
   for (int j = 0; j < n; j++) {
   double t = LU[p][j]; LU[p][j] = LU[k][j]; LU[k][j] = t;
   }
   int t = piv[p]; piv[p] = piv[k]; piv[k] = t;
   pivsign = -pivsign;
   }
   // Compute multipliers and eliminate k-th column.
   if (LU[k][k] != 0.0) {
   for (int i = k+1; i < m; i++) {
   LU[i][k] /= LU[k][k];
   for (int j = k+1; j < n; j++) {
   LU[i][j] -= LU[i][k]*LU[k][j];
   }
   }
   }
   }
   }
   
   \* ------------------------
   End of temporary code.
   * ------------------------ */

  /* ------------------------
   Public Methods
   * ------------------------ */

  /** Is the matrix nonsingular?
   @return     true if U, and hence A, is nonsingular.
   */

  public boolean isNonsingular () {
    for (int j = 0; j < n; j++) {
      if (LU[j][j] == 0)
        return false;
    }
    return true;
  }

  /** Return lower triangular factor
   @return     L
   */

  public Matrix getL () {
    Matrix X = new Matrix(m, n);
    double[][] L = X.getArray();
    for (int i = 0; i < m; i++) {
      for (int j = 0; j < n; j++) {
        if (i > j) {
          L[i][j] = LU[i][j];
        } else if (i == j) {
          L[i][j] = 1.0;
        } else {
          L[i][j] = 0.0;
        }
      }
    }
    return X;
  }

  /** Return upper triangular factor
   @return     U
   */

  public Matrix getU () {
    Matrix X = new Matrix(n, n);
    double[][] U = X.getArray();
    for (int i = 0; i < n; i++) {
      for (int j = 0; j < n; j++) {
        if (i <= j) {
          U[i][j] = LU[i][j];
        } else {
          U[i][j] = 0.0;
        }
      }
    }
    return X;
  }

  /** Return pivot permutation vector
   @return     piv
   */

  public int[] getPivot () {
    int[] p = new int[m];
    for (int i = 0; i < m; i++) {
      p[i] = piv[i];
    }
    return p;
  }

  /** Return pivot permutation vector as a one-dimensional double array
   @return     (double) piv
   */

  public double[] getDoublePivot () {
    double[] vals = new double[m];
    for (int i = 0; i < m; i++) {
      vals[i] = (double) piv[i];
    }
    return vals;
  }

  /** Determinant
   @return     det(A)
   @exception  IllegalArgumentException  Matrix must be square
   */

  public double det () {
    if (m != n) {
      throw new IllegalArgumentException("Matrix must be square.");
    }
    double d = (double) pivsign;
    for (int j = 0; j < n; j++) {
      d *= LU[j][j];
    }
    return d;
  }

  /** Solve A*X = B
   @param  B   A Matrix with as many rows as A and any number of columns.
   @return     X so that L*U*X = B(piv,:)
   @exception  IllegalArgumentException Matrix row dimensions must agree.
   @exception  RuntimeException  Matrix is singular.
   */

  public Matrix solve (Matrix B) {
    if (B.getRowDimension() != m) {
      throw new IllegalArgumentException("Matrix row dimensions must agree.");
    }
    if (!this.isNonsingular()) {
      throw new RuntimeException("Matrix is singular.");
    }

    // Copy right hand side with pivoting
    int nx = B.getColumnDimension();
    Matrix Xmat = B.getMatrix(piv, 0, nx-1);
    double[][] X = Xmat.getArray();

    // Solve L*Y = B(piv,:)
    for (int k = 0; k < n; k++) {
      for (int i = k+1; i < n; i++) {
        for (int j = 0; j < nx; j++) {
          X[i][j] -= X[k][j]*LU[i][k];
        }
      }
    }
    // Solve U*X = Y;
    for (int k = n-1; k >= 0; k--) {
      for (int j = 0; j < nx; j++) {
        X[k][j] /= LU[k][k];
      }
      for (int i = 0; i < k; i++) {
        for (int j = 0; j < nx; j++) {
          X[i][j] -= X[k][j]*LU[i][k];
        }
      }
    }
    return Xmat;
  }
}

/**
 Jama = Java Matrix class.
 <P>
 The Java Matrix Class provides the fundamental operations of numerical
 linear algebra.  Various constructors create Matrices from two dimensional
 arrays of double precision floating point numbers.  Various "gets" and
 "sets" provide access to submatrices and matrix elements.  Several methods 
 implement basic matrix arithmetic, including matrix addition and
 multiplication, matrix norms, and element-by-element array operations.
 Methods for reading and printing matrices are also included.  All the
 operations in this version of the Matrix Class involve real matrices.
 Complex matrices may be handled in a future version.
 <P>
 Five fundamental matrix decompositions, which consist of pairs or triples
 of matrices, permutation vectors, and the like, produce results in five
 decomposition classes.  These decompositions are accessed by the Matrix
 class to compute solutions of simultaneous linear equations, determinants,
 inverses and other matrix functions.  The five decompositions are:
 <P><UL>
 <LI>Cholesky Decomposition of symmetric, positive definite matrices.
 <LI>LU Decomposition of rectangular matrices.
 <LI>QR Decomposition of rectangular matrices.
 <LI>Singular Value Decomposition of rectangular matrices.
 <LI>Eigenvalue Decomposition of both symmetric and nonsymmetric square matrices.
 </UL>
 <DL>
 <DT><B>Example of use:</B></DT>
 <P>
 <DD>Solve a linear system A x = b and compute the residual norm, ||b - A x||.
 <P><PRE>
 double[][] vals = {{1.,2.,3},{4.,5.,6.},{7.,8.,10.}};
 Matrix A = new Matrix(vals);
 Matrix b = Matrix.random(3,1);
 Matrix x = A.solve(b);
 Matrix r = A.times(x).minus(b);
 double rnorm = r.normInf();
 </PRE></DD>
 </DL>
 
 @author The MathWorks, Inc. and the National Institute of Standards and Technology.
 @version 5 August 1998
 */

public class Matrix implements Cloneable, java.io.Serializable {

  /* ------------------------
   Class variables
   * ------------------------ */

  /** Array for internal storage of elements.
   @serial internal array storage.
   */
  private double[][] A;

  /** Row and column dimensions.
   @serial row dimension.
   @serial column dimension.
   */
  private int m, n;

  /* ------------------------
   Constructors
   * ------------------------ */

  /** Construct an m-by-n matrix of zeros. 
   @param m    Number of rows.
   @param n    Number of colums.
   */

  public Matrix (int m, int n) {
    this.m = m;
    this.n = n;
    A = new double[m][n];
  }

  /** Construct an m-by-n constant matrix.
   @param m    Number of rows.
   @param n    Number of colums.
   @param s    Fill the matrix with this scalar value.
   */

  public Matrix (int m, int n, double s) {
    this.m = m;
    this.n = n;
    A = new double[m][n];
    for (int i = 0; i < m; i++) {
      for (int j = 0; j < n; j++) {
        A[i][j] = s;
      }
    }
  }

  /** Construct a matrix from a 2-D array.
   @param A    Two-dimensional array of doubles.
   @exception  IllegalArgumentException All rows must have the same length
   @see        #constructWithCopy
   */

  public Matrix (double[][] A) {
    m = A.length;
    n = A[0].length;
    for (int i = 0; i < m; i++) {
      if (A[i].length != n) {
        throw new IllegalArgumentException("All rows must have the same length.");
      }
    }
    this.A = A;
  }

  /** Construct a matrix quickly without checking arguments.
   @param A    Two-dimensional array of doubles.
   @param m    Number of rows.
   @param n    Number of colums.
   */

  public Matrix (double[][] A, int m, int n) {
    this.A = A;
    this.m = m;
    this.n = n;
  }

  /** Construct a matrix from a one-dimensional packed array
   @param vals One-dimensional array of doubles, packed by columns (ala Fortran).
   @param m    Number of rows.
   @exception  IllegalArgumentException Array length must be a multiple of m.
   */

  public Matrix (double vals[], int m) {
    this.m = m;
    n = (m != 0 ? vals.length/m : 0);
    if (m*n != vals.length) {
      throw new IllegalArgumentException("Array length must be a multiple of m.");
    }
    A = new double[m][n];
    for (int i = 0; i < m; i++) {
      for (int j = 0; j < n; j++) {
        A[i][j] = vals[i+j*m];
      }
    }
  }

  /* ------------------------
   Public Methods
   * ------------------------ */

  /** Construct a matrix from a copy of a 2-D array.
   @param A    Two-dimensional array of doubles.
   @exception  IllegalArgumentException All rows must have the same length
   
   public static Matrix constructWithCopy(double[][] A) {
   int m = A.length;
   int n = A[0].length;
   Matrix X = new Matrix(m,n);
   double[][] C = X.getArray();
   for (int i = 0; i < m; i++) {
   if (A[i].length != n) {
   throw new IllegalArgumentException
   ("All rows must have the same length.");
   }
   for (int j = 0; j < n; j++) {
   C[i][j] = A[i][j];
   }
   }
   return X;
   }
   */

  /** Make a deep copy of a matrix
   */

  public Matrix copy () {
    Matrix X = new Matrix(m, n);
    double[][] C = X.getArray();
    for (int i = 0; i < m; i++) {
      for (int j = 0; j < n; j++) {
        C[i][j] = A[i][j];
      }
    }
    return X;
  }

  /** Clone the Matrix object.
   */

  public Object clone () {
    return this.copy();
  }

  /** Access the internal two-dimensional array.
   @return     Pointer to the two-dimensional array of matrix elements.
   */

  public double[][] getArray () {
    return A;
  }

  /** Copy the internal two-dimensional array.
   @return     Two-dimensional array copy of matrix elements.
   */

  public double[][] getArrayCopy () {
    double[][] C = new double[m][n];
    for (int i = 0; i < m; i++) {
      for (int j = 0; j < n; j++) {
        C[i][j] = A[i][j];
      }
    }
    return C;
  }

  /** Make a one-dimensional column packed copy of the internal array.
   @return     Matrix elements packed in a one-dimensional array by columns.
   */

  public double[] getColumnPackedCopy () {
    double[] vals = new double[m*n];
    for (int i = 0; i < m; i++) {
      for (int j = 0; j < n; j++) {
        vals[i+j*m] = A[i][j];
      }
    }
    return vals;
  }

  /** Make a one-dimensional row packed copy of the internal array.
   @return     Matrix elements packed in a one-dimensional array by rows.
   */

  public double[] getRowPackedCopy () {
    double[] vals = new double[m*n];
    for (int i = 0; i < m; i++) {
      for (int j = 0; j < n; j++) {
        vals[i*n+j] = A[i][j];
      }
    }
    return vals;
  }

  /** Get row dimension.
   @return     m, the number of rows.
   */

  public int getRowDimension () {
    return m;
  }

  /** Get column dimension.
   @return     n, the number of columns.
   */

  public int getColumnDimension () {
    return n;
  }

  /** Get a single element.
   @param i    Row index.
   @param j    Column index.
   @return     A(i,j)
   @exception  ArrayIndexOutOfBoundsException
   */

  public double get (int i, int j) {
    return A[i][j];
  }

  /** Get a submatrix.
   @param i0   Initial row index
   @param i1   Final row index
   @param j0   Initial column index
   @param j1   Final column index
   @return     A(i0:i1,j0:j1)
   @exception  ArrayIndexOutOfBoundsException Submatrix indices
   */

  public Matrix getMatrix (int i0, int i1, int j0, int j1) {
    Matrix X = new Matrix(i1-i0+1, j1-j0+1);
    double[][] B = X.getArray();
    try {
      for (int i = i0; i <= i1; i++) {
        for (int j = j0; j <= j1; j++) {
          B[i-i0][j-j0] = A[i][j];
        }
      }
    } 
    catch(ArrayIndexOutOfBoundsException e) {
      throw new ArrayIndexOutOfBoundsException("Submatrix indices");
    }
    return X;
  }

  /** Get a submatrix.
   @param r    Array of row indices.
   @param c    Array of column indices.
   @return     A(r(:),c(:))
   @exception  ArrayIndexOutOfBoundsException Submatrix indices
   */

  public Matrix getMatrix (int[] r, int[] c) {
    Matrix X = new Matrix(r.length, c.length);
    double[][] B = X.getArray();
    try {
      for (int i = 0; i < r.length; i++) {
        for (int j = 0; j < c.length; j++) {
          B[i][j] = A[r[i]][c[j]];
        }
      }
    } 
    catch(ArrayIndexOutOfBoundsException e) {
      throw new ArrayIndexOutOfBoundsException("Submatrix indices");
    }
    return X;
  }

  /** Get a submatrix.
   @param i0   Initial row index
   @param i1   Final row index
   @param c    Array of column indices.
   @return     A(i0:i1,c(:))
   @exception  ArrayIndexOutOfBoundsException Submatrix indices
   */

  public Matrix getMatrix (int i0, int i1, int[] c) {
    Matrix X = new Matrix(i1-i0+1, c.length);
    double[][] B = X.getArray();
    try {
      for (int i = i0; i <= i1; i++) {
        for (int j = 0; j < c.length; j++) {
          B[i-i0][j] = A[i][c[j]];
        }
      }
    } 
    catch(ArrayIndexOutOfBoundsException e) {
      throw new ArrayIndexOutOfBoundsException("Submatrix indices");
    }
    return X;
  }

  /** Get a submatrix.
   @param r    Array of row indices.
   @param i0   Initial column index
   @param i1   Final column index
   @return     A(r(:),j0:j1)
   @exception  ArrayIndexOutOfBoundsException Submatrix indices
   */

  public Matrix getMatrix (int[] r, int j0, int j1) {
    Matrix X = new Matrix(r.length, j1-j0+1);
    double[][] B = X.getArray();
    try {
      for (int i = 0; i < r.length; i++) {
        for (int j = j0; j <= j1; j++) {
          B[i][j-j0] = A[r[i]][j];
        }
      }
    } 
    catch(ArrayIndexOutOfBoundsException e) {
      throw new ArrayIndexOutOfBoundsException("Submatrix indices");
    }
    return X;
  }

  /** Set a single element.
   @param i    Row index.
   @param j    Column index.
   @param s    A(i,j).
   @exception  ArrayIndexOutOfBoundsException
   */

  public void set (int i, int j, double s) {
    A[i][j] = s;
  }

  /** Set a submatrix.
   @param i0   Initial row index
   @param i1   Final row index
   @param j0   Initial column index
   @param j1   Final column index
   @param X    A(i0:i1,j0:j1)
   @exception  ArrayIndexOutOfBoundsException Submatrix indices
   */

  public void setMatrix (int i0, int i1, int j0, int j1, Matrix X) {
    try {
      for (int i = i0; i <= i1; i++) {
        for (int j = j0; j <= j1; j++) {
          A[i][j] = X.get(i-i0, j-j0);
        }
      }
    } 
    catch(ArrayIndexOutOfBoundsException e) {
      throw new ArrayIndexOutOfBoundsException("Submatrix indices");
    }
  }

  /** Set a submatrix.
   @param r    Array of row indices.
   @param c    Array of column indices.
   @param X    A(r(:),c(:))
   @exception  ArrayIndexOutOfBoundsException Submatrix indices
   */

  public void setMatrix (int[] r, int[] c, Matrix X) {
    try {
      for (int i = 0; i < r.length; i++) {
        for (int j = 0; j < c.length; j++) {
          A[r[i]][c[j]] = X.get(i, j);
        }
      }
    } 
    catch(ArrayIndexOutOfBoundsException e) {
      throw new ArrayIndexOutOfBoundsException("Submatrix indices");
    }
  }

  /** Set a submatrix.
   @param r    Array of row indices.
   @param j0   Initial column index
   @param j1   Final column index
   @param X    A(r(:),j0:j1)
   @exception  ArrayIndexOutOfBoundsException Submatrix indices
   */

  public void setMatrix (int[] r, int j0, int j1, Matrix X) {
    try {
      for (int i = 0; i < r.length; i++) {
        for (int j = j0; j <= j1; j++) {
          A[r[i]][j] = X.get(i, j-j0);
        }
      }
    } 
    catch(ArrayIndexOutOfBoundsException e) {
      throw new ArrayIndexOutOfBoundsException("Submatrix indices");
    }
  }

  /** Set a submatrix.
   @param i0   Initial row index
   @param i1   Final row index
   @param c    Array of column indices.
   @param X    A(i0:i1,c(:))
   @exception  ArrayIndexOutOfBoundsException Submatrix indices
   */

  public void setMatrix (int i0, int i1, int[] c, Matrix X) {
    try {
      for (int i = i0; i <= i1; i++) {
        for (int j = 0; j < c.length; j++) {
          A[i][c[j]] = X.get(i-i0, j);
        }
      }
    } 
    catch(ArrayIndexOutOfBoundsException e) {
      throw new ArrayIndexOutOfBoundsException("Submatrix indices");
    }
  }

  /** Matrix transpose.
   @return    A'
   */

  public Matrix transpose () {
    Matrix X = new Matrix(n, m);
    double[][] C = X.getArray();
    for (int i = 0; i < m; i++) {
      for (int j = 0; j < n; j++) {
        C[j][i] = A[i][j];
      }
    }
    return X;
  }

  /** One norm
   @return    maximum column sum.
   */

  public double norm1 () {
    double f = 0;
    for (int j = 0; j < n; j++) {
      double s = 0;
      for (int i = 0; i < m; i++) {
        s += Math.abs(A[i][j]);
      }
      f = Math.max(f, s);
    }
    return f;
  }

  /** Two norm
   @return    maximum singular value.
   */

  public double norm2 () {
    return (new SingularValueDecomposition(this).norm2());
  }

  /** Infinity norm
   @return    maximum row sum.
   */

  public double normInf () {
    double f = 0;
    for (int i = 0; i < m; i++) {
      double s = 0;
      for (int j = 0; j < n; j++) {
        s += Math.abs(A[i][j]);
      }
      f = Math.max(f, s);
    }
    return f;
  }

  /** Frobenius norm
   @return    sqrt of sum of squares of all elements.
   */

  public double normF () {
    double f = 0;
    for (int i = 0; i < m; i++) {
      for (int j = 0; j < n; j++) {
        f = new Maths().hypot(f, A[i][j]);
      }
    }
    return f;
  }

  /**  Unary minus
   @return    -A
   */

  public Matrix uminus () {
    Matrix X = new Matrix(m, n);
    double[][] C = X.getArray();
    for (int i = 0; i < m; i++) {
      for (int j = 0; j < n; j++) {
        C[i][j] = -A[i][j];
      }
    }
    return X;
  }

  /** C = A + B
   @param B    another matrix
   @return     A + B
   */

  public Matrix plus (Matrix B) {
    checkMatrixDimensions(B);
    Matrix X = new Matrix(m, n);
    double[][] C = X.getArray();
    for (int i = 0; i < m; i++) {
      for (int j = 0; j < n; j++) {
        C[i][j] = A[i][j] + B.A[i][j];
      }
    }
    return X;
  }

  /** A = A + B
   @param B    another matrix
   @return     A + B
   */

  public Matrix plusEquals (Matrix B) {
    checkMatrixDimensions(B);
    for (int i = 0; i < m; i++) {
      for (int j = 0; j < n; j++) {
        A[i][j] = A[i][j] + B.A[i][j];
      }
    }
    return this;
  }

  /** C = A - B
   @param B    another matrix
   @return     A - B
   */

  public Matrix minus (Matrix B) {
    checkMatrixDimensions(B);
    Matrix X = new Matrix(m, n);
    double[][] C = X.getArray();
    for (int i = 0; i < m; i++) {
      for (int j = 0; j < n; j++) {
        C[i][j] = A[i][j] - B.A[i][j];
      }
    }
    return X;
  }

  /** A = A - B
   @param B    another matrix
   @return     A - B
   */

  public Matrix minusEquals (Matrix B) {
    checkMatrixDimensions(B);
    for (int i = 0; i < m; i++) {
      for (int j = 0; j < n; j++) {
        A[i][j] = A[i][j] - B.A[i][j];
      }
    }
    return this;
  }

  /** Element-by-element multiplication, C = A.*B
   @param B    another matrix
   @return     A.*B
   */

  public Matrix arrayTimes (Matrix B) {
    checkMatrixDimensions(B);
    Matrix X = new Matrix(m, n);
    double[][] C = X.getArray();
    for (int i = 0; i < m; i++) {
      for (int j = 0; j < n; j++) {
        C[i][j] = A[i][j] * B.A[i][j];
      }
    }
    return X;
  }

  /** Element-by-element multiplication in place, A = A.*B
   @param B    another matrix
   @return     A.*B
   */

  public Matrix arrayTimesEquals (Matrix B) {
    checkMatrixDimensions(B);
    for (int i = 0; i < m; i++) {
      for (int j = 0; j < n; j++) {
        A[i][j] = A[i][j] * B.A[i][j];
      }
    }
    return this;
  }

  /** Element-by-element right division, C = A./B
   @param B    another matrix
   @return     A./B
   */

  public Matrix arrayRightDivide (Matrix B) {
    checkMatrixDimensions(B);
    Matrix X = new Matrix(m, n);
    double[][] C = X.getArray();
    for (int i = 0; i < m; i++) {
      for (int j = 0; j < n; j++) {
        C[i][j] = A[i][j] / B.A[i][j];
      }
    }
    return X;
  }

  /** Element-by-element right division in place, A = A./B
   @param B    another matrix
   @return     A./B
   */

  public Matrix arrayRightDivideEquals (Matrix B) {
    checkMatrixDimensions(B);
    for (int i = 0; i < m; i++) {
      for (int j = 0; j < n; j++) {
        A[i][j] = A[i][j] / B.A[i][j];
      }
    }
    return this;
  }

  /** Element-by-element left division, C = A.\B
   @param B    another matrix
   @return     A.\B
   */

  public Matrix arrayLeftDivide (Matrix B) {
    checkMatrixDimensions(B);
    Matrix X = new Matrix(m, n);
    double[][] C = X.getArray();
    for (int i = 0; i < m; i++) {
      for (int j = 0; j < n; j++) {
        C[i][j] = B.A[i][j] / A[i][j];
      }
    }
    return X;
  }

  /** Element-by-element left division in place, A = A.\B
   @param B    another matrix
   @return     A.\B
   */

  public Matrix arrayLeftDivideEquals (Matrix B) {
    checkMatrixDimensions(B);
    for (int i = 0; i < m; i++) {
      for (int j = 0; j < n; j++) {
        A[i][j] = B.A[i][j] / A[i][j];
      }
    }
    return this;
  }

  /** Multiply a matrix by a scalar, C = s*A
   @param s    scalar
   @return     s*A
   */

  public Matrix times (double s) {
    Matrix X = new Matrix(m, n);
    double[][] C = X.getArray();
    for (int i = 0; i < m; i++) {
      for (int j = 0; j < n; j++) {
        C[i][j] = s*A[i][j];
      }
    }
    return X;
  }

  /** Multiply a matrix by a scalar in place, A = s*A
   @param s    scalar
   @return     replace A by s*A
   */

  public Matrix timesEquals (double s) {
    for (int i = 0; i < m; i++) {
      for (int j = 0; j < n; j++) {
        A[i][j] = s*A[i][j];
      }
    }
    return this;
  }

  /** Linear algebraic matrix multiplication, A * B
   @param B    another matrix
   @return     Matrix product, A * B
   @exception  IllegalArgumentException Matrix inner dimensions must agree.
   */

  public Matrix times (Matrix B) {
    if (B.m != n) {
      throw new IllegalArgumentException("Matrix inner dimensions must agree.");
    }
    Matrix X = new Matrix(m, B.n);
    double[][] C = X.getArray();
    double[] Bcolj = new double[n];
    for (int j = 0; j < B.n; j++) {
      for (int k = 0; k < n; k++) {
        Bcolj[k] = B.A[k][j];
      }
      for (int i = 0; i < m; i++) {
        double[] Arowi = A[i];
        double s = 0;
        for (int k = 0; k < n; k++) {
          s += Arowi[k]*Bcolj[k];
        }
        C[i][j] = s;
      }
    }
    return X;
  }

  /** Matrix inverse or pseudoinverse
   @return     inverse(A) if A is square, pseudoinverse otherwise.
   */

  public Matrix inverse () {

    Matrix identity = new Matrix(m, m);
    double[][] X = identity.getArray();
    for (int i = 0; i < m; i++) {
      for (int j = 0; j < n; j++) {
        X[i][j] = (i == j ? 1.0 : 0.0);
      }
    }

    return new LUDecomposition(this).solve(identity);
  }

  /** Singular Value Decomposition
   @return     SingularValueDecomposition
   @see SingularValueDecomposition
   */

  public SingularValueDecomposition svd () {
    return new SingularValueDecomposition(this);
  }

  /** Matrix rank
   @return     effective numerical rank, obtained from SVD.
   */

  public int rank () {
    return new SingularValueDecomposition(this).rank();
  }

  /** Matrix condition (2 norm)
   @return     ratio of largest to smallest singular value.
   */

  public double cond () {
    return new SingularValueDecomposition(this).cond();
  }

  /** Matrix trace.
   @return     sum of the diagonal elements.
   */

  public double trace () {
    double t = 0;
    for (int i = 0; i < Math.min(m, n); i++) {
      t += A[i][i];
    }
    return t;
  }


   /** Print the matrix to stdout.   Line the elements up in columns
     * with a Fortran-like 'Fw.d' style format.
   @param w    Column width.
   @param d    Number of digits after the decimal.
   */

   public void print (int w, int d) {
      print(new PrintWriter(System.out,true),w,d); }

   /** Print the matrix to the output stream.   Line the elements up in
     * columns with a Fortran-like 'Fw.d' style format.
   @param output Output stream.
   @param w      Column width.
   @param d      Number of digits after the decimal.
   */

   public void print (PrintWriter output, int w, int d) {
      DecimalFormat format = new DecimalFormat();
      format.setDecimalFormatSymbols(new DecimalFormatSymbols(Locale.US));
      format.setMinimumIntegerDigits(1);
      format.setMaximumFractionDigits(d);
      format.setMinimumFractionDigits(d);
      format.setGroupingUsed(false);
      print(output,format,w+2);
   }

   /** Print the matrix to stdout.  Line the elements up in columns.
     * Use the format object, and right justify within columns of width
     * characters.
     * Note that is the matrix is to be read back in, you probably will want
     * to use a NumberFormat that is set to US Locale.
   @param format A  Formatting object for individual elements.
   @param width     Field width for each column.
   @see java.text.DecimalFormat#setDecimalFormatSymbols
   */

   public void print (NumberFormat format, int width) {
      print(new PrintWriter(System.out,true),format,width); }

   // DecimalFormat is a little disappointing coming from Fortran or C's printf.
   // Since it doesn't pad on the left, the elements will come out different
   // widths.  Consequently, we'll pass the desired column width in as an
   // argument and do the extra padding ourselves.

   /** Print the matrix to the output stream.  Line the elements up in columns.
     * Use the format object, and right justify within columns of width
     * characters.
     * Note that is the matrix is to be read back in, you probably will want
     * to use a NumberFormat that is set to US Locale.
   @param output the output stream.
   @param format A formatting object to format the matrix elements 
   @param width  Column width.
   @see java.text.DecimalFormat#setDecimalFormatSymbols
   */

   public void print (PrintWriter output, NumberFormat format, int width) {
      output.println();  // start on new line.
      for (int i = 0; i < m; i++) {
         for (int j = 0; j < n; j++) {
            String s = format.format(A[i][j]); // format the number
            int padding = Math.max(1,width-s.length()); // At _least_ 1 space
            for (int k = 0; k < padding; k++)
               output.print(' ');
            output.print(s);
         }
         output.println();
      }
      output.println();   // end with blank line.
   }

  /* ------------------------
   Private Methods
   * ------------------------ */

  /** Check if size(A) == size(B) **/

  private void checkMatrixDimensions (Matrix B) {
    if (B.m != m || B.n != n) {
      throw new IllegalArgumentException("Matrix dimensions must agree.");
    }
  }
}
